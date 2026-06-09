import { common } from '@kit.AbilityKit'
import { curves, promptAction } from '@kit.ArkUI'
import { fileIo } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { http } from '@kit.NetworkKit'
import {
  AppStrings,
  connectImagePreviewAction,
  connectLayoutSafeArea,
  connectNavStack,
  heroIdForUrl,
  ImagePreviewActionState,
  LayoutSafeAreaState,
  MediaUrlUtils,
  NetworkProxyRequest,
  ThemeConstants,
} from 'shared'
import { ImagePreviewCoordinator } from '../model/ImagePreviewCoordinator'

const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 30000
// Swipe-down-to-dismiss thresholds (at fit only): drag past this distance OR fling faster than this velocity.
const DISMISS_DISTANCE_VP: number = 140
const DISMISS_VELOCITY: number = 1000

interface ImageDownloadResult {
  buffer: ArrayBuffer
  contentType: string
}

// Partial view of the Image.onComplete event (structural; the framework passes a richer object). width/height
// are the bitmap's INTRINSIC pixel size — we fit them to the viewport ourselves (ImagePreviewCoordinator
// .fitScale) rather than trusting contentWidth, which keeps the math explicit and correct under ImageFit.Contain.
interface ImagePreviewLoadEvent {
  loadingStatus: number
  width?: number
  height?: number
  componentWidth?: number
  componentHeight?: number
}
@ComponentV2
export struct ImagePreviewPage {
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder); method target only.
  private stack: NavPathStack = connectNavStack().stack;
  @Param url: string = '';

  // Viewport (vp), measured from .onAreaChange — both axes are needed for the focal/clamp math.
  @Local private viewportWidth: number = 0;
  @Local private viewportHeight: number = 0;
  // Transform state (vp). The image is a single viewport-sized element transformed by .scale()+.translate()
  // about its CENTER — NOT the old width-scaling + nested Scroll. All three are flat @Local primitives so
  // animateTo behaves under State Management V2.
  @Local private scaleValue: number = 1;
  @Local private offsetX: number = 0;
  @Local private offsetY: number = 0;
  // Intrinsic bitmap size (vp), captured on load; fitted to the viewport on demand for the pan bounds.
  @Local private intrinsicW: number = 0;
  @Local private intrinsicH: number = 0;
  // Swipe-down-to-dismiss (armed only at fit): extra downward translate + backdrop fade.
  @Local private dismissY: number = 0;
  // The dragged offset BAKED into a layout-honored .offset() at release time. geometryTransition captures the
  // LAYOUT rect, NOT the render .translate, so the back Hero morph would otherwise start from the centered
  // frame; baking the release offset here makes it start from where the finger let go. (Pattern from the
  // official ShowLargeImageWithGesture sample, which bakes the dragged rect into .position before morphing.)
  @Local private dismissLayoutY: number = 0;
  @Local private backdropAlpha: number = 1;
  @Local private isSaving: boolean = false;
  // V2 mirror of the one-directional IMAGE_PREVIEW_ACTION appbar command (Index dual-writes).
  @Local private imgAction: ImagePreviewActionState = connectImagePreviewAction();
  // Window safe-area metrics (AppStorageV2 mirror; EntryAbility publishes V2-only).
  private layout: LayoutSafeAreaState = connectLayoutSafeArea();

  // Gesture snapshots (captured at gesture start so each update resolves against a fixed base, not the
  // previous frame — keeps focal/pan math stable). Plain fields, not observable state.
  private pinchStartScale: number = 1;
  private pinchStartOffX: number = 0;
  private pinchStartOffY: number = 0;
  private pinchCenterStartX: number = 0;
  private pinchCenterStartY: number = 0;
  private panStartOffX: number = 0;
  private panStartOffY: number = 0;
  // Pan must stand down while a 2-finger pinch is in flight (GestureMode.Parallel lets both fire, and a
  // pinch reads as two pans that would fight the focal write).
  private isPinching: boolean = false;

  private clampScale(value: number): number {
    return ImagePreviewCoordinator.clampScale(value)
  }

  // Fitted (drawn) image size in vp = intrinsic * Contain fit-factor. Pan bounds use this, never intrinsic.
  private displayWidth(): number {
    return (
      this.intrinsicW *
      ImagePreviewCoordinator.fitScale(
        this.viewportWidth,
        this.viewportHeight,
        this.intrinsicW,
        this.intrinsicH,
      )
    )
  }

  private displayHeight(): number {
    return (
      this.intrinsicH *
      ImagePreviewCoordinator.fitScale(
        this.viewportWidth,
        this.viewportHeight,
        this.intrinsicW,
        this.intrinsicH,
      )
    )
  }

  private clampOffsetX(value: number, scale: number): number {
    return ImagePreviewCoordinator.clampOffset(
      value,
      this.viewportWidth,
      this.displayWidth(),
      scale,
    )
  }

  private clampOffsetY(value: number, scale: number): number {
    return ImagePreviewCoordinator.clampOffset(
      value,
      this.viewportHeight,
      this.displayHeight(),
      scale,
    )
  }

  private normalizedUrl(): string {
    return MediaUrlUtils.normalizeUrl(this.url)
  }

  // This preview's geometryTransition id (the IN node); the source thumbnail derives the SAME id from the
  // same normalized URL via heroIdForUrl, which pairs the two across the route push. Always bound — an open
  // with no matching source (e.g. a deep link) is a lone node that simply fades in via .transition(OPACITY).
  private heroGid(): string {
    return heroIdForUrl(this.normalizedUrl())
  }

  // Black backdrop whose alpha fades while swiping down to dismiss (1 = opaque, lower = revealing).
  private backdropColor(): string {
    const a: number = Math.round(Math.max(0, Math.min(1, this.backdropAlpha)) * 255)
    const hex: string = a < 16 ? `0${a.toString(16)}` : a.toString(16)
    return `#${hex}000000`
  }

  @Monitor('imgAction.command')
  private onImagePreviewActionCommand(): void {
    if (ImagePreviewCoordinator.actionFromCommand(this.imgAction.command) === 'save') {
      this.saveImage()
    }
  }

  // Double-tap: zoom toward the tapped point (fit -> DOUBLE_TAP_SCALE) or spring back to fit. Center-pivot
  // .scale(): to keep the tapped screen point stationary, the corrective translate is (1-T)*(tap - center).
  private applyDoubleTap(tapX: number, tapY: number): void {
    if (this.scaleValue > 1.01) {
      this.animateReset()
      return
    }
    const target: number = ImagePreviewCoordinator.DOUBLE_TAP_SCALE
    const ox: number = (1 - target) * (tapX - this.viewportWidth / 2)
    const oy: number = (1 - target) * (tapY - this.viewportHeight / 2)
    this.getUIContext().animateTo({ curve: Curve.FastOutSlowIn, duration: 240 }, () => {
      this.scaleValue = target
      this.offsetX = this.clampOffsetX(ox, target)
      this.offsetY = this.clampOffsetY(oy, target)
    })
  }

  private animateReset(): void {
    this.getUIContext().animateTo({ curve: curves.springMotion() }, () => {
      this.scaleValue = 1
      this.offsetX = 0
      this.offsetY = 0
    })
  }

  // After a pinch ends, snap a sub-fit scale back to fit (offsets to 0) and re-clamp any over-pan.
  private snapBack(): void {
    this.getUIContext().animateTo({ curve: curves.springMotion() }, () => {
      const s: number = this.clampScale(this.scaleValue)
      this.scaleValue = s
      if (s <= 1.01) {
        this.offsetX = 0
        this.offsetY = 0
      } else {
        this.offsetX = this.clampOffsetX(this.offsetX, s)
        this.offsetY = this.clampOffsetY(this.offsetY, s)
      }
    })
  }

  private endDismissGesture(velocityY: number): void {
    if (this.dismissY > DISMISS_DISTANCE_VP || velocityY > DISMISS_VELOCITY) {
      // Bake the live drag (a render .translate, which geometryTransition does NOT capture) into the layout
      // .offset (which it DOES) and zero the render translate — the visual position is unchanged in this same
      // frame — so the back Hero morph starts from where the finger let go instead of the centered frame.
      // geometryTransition then OWNS the position/size morph (it overrides the offset during the animateTo),
      // so dismissLayoutY is set once and not animated. (Pattern from the official ShowLargeImageWithGesture.)
      this.dismissLayoutY = this.dismissY
      this.dismissY = 0
      // Close via the shared-element (Hero) morph: pop INSIDE animateTo (animated=false suppresses the HDS
      // default route animation) so the image frame morphs back to the source thumbnail while the backdrop fades.
      this.getUIContext().animateTo(
        {
          duration: 300,
          curve: Curve.Friction,
        },
        () => {
          this.backdropAlpha = 0
          this.stack.pop(false)
        },
      )
    } else {
      this.getUIContext().animateTo({ curve: curves.springMotion() }, () => {
        this.dismissY = 0
        this.backdropAlpha = 1
      })
    }
  }

  private showToast(message: string): void {
    promptAction.openToast({ message: message }).catch((_error: Error) => {})
  }

  private async saveImage(): Promise<void> {
    if (this.isSaving) {
      return
    }
    const imageUrl = this.normalizedUrl()
    if (!MediaUrlUtils.isHttpUrl(imageUrl)) {
      this.showToast(
        AppStrings.text($r('app.string.image_preview_invalid_url'), 'Invalid image URL'),
      )
      return
    }

    let tempPath = ''
    this.isSaving = true
    this.showToast(
      AppStrings.text($r('app.string.image_preview_downloading'), 'Downloading image…'),
    )
    try {
      const result = await this.downloadImage(imageUrl)
      if (result.contentType && result.contentType.toLowerCase().indexOf('image/') !== 0) {
        throw new Error(
          AppStrings.text(
            $r('app.string.image_preview_not_an_image'),
            'The link did not return an image',
          ),
        )
      }
      const extension = MediaUrlUtils.preferredImageExtension(imageUrl, result.contentType)
      const title = MediaUrlUtils.imageTitleFromUrl(imageUrl)
      tempPath = this.writeTempImage(result.buffer, extension)

      this.showToast(
        AppStrings.text(
          $r('app.string.image_preview_choose_save_location'),
          'Please choose a save location',
        ),
      )
      await this.copySandboxImageToPhotos(tempPath, title, extension)
      this.showToast(AppStrings.text($r('app.string.image_saved_to_gallery'), 'Saved to Gallery'))
    } catch (error) {
      const e = error as Error
      this.showToast(
        e.message || AppStrings.text($r('app.string.image_preview_save_failed'), 'Save failed'),
      )
    } finally {
      if (tempPath) {
        this.removeTempImage(tempPath)
      }
      this.isSaving = false
    }
  }

  private async downloadImage(imageUrl: string): Promise<ImageDownloadResult> {
    let headerBag: Object | null = null

    try {
      const response = await NetworkProxyRequest.request(imageUrl, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'image/avif,image/webp,image/png,image/svg+xml,image/*,*/*;q=0.8',
          'Accept-Encoding': 'gzip',
          'User-Agent': 'Mozilla/5.0',
        },
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: false,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        onHeadersReceive: (headers: Object) => {
          headerBag = headers
        },
      })
      const statusCode = response.responseCode as number
      if (statusCode < 200 || statusCode >= 300) {
        throw new Error(`HTTP ${statusCode}`)
      }
      return {
        buffer: response.result as ArrayBuffer,
        contentType: ImagePreviewCoordinator.extractHeaderValue(
          headerBag || response.header,
          'content-type',
        ),
      }
    } catch (error) {
      const e = error as Error
      throw new Error(
        e.message ||
          AppStrings.text($r('app.string.image_preview_download_failed'), 'Image download failed'),
      )
    }
  }

  private writeTempImage(buffer: ArrayBuffer, extension: string): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const filePath = `${context.filesDir}/v2next_image_${Date.now()}.${extension}`
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(
        filePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      fileIo.writeSync(file.fd, buffer)
      return filePath
    } catch (error) {
      const e = error as Error
      throw new Error(
        e.message ||
          AppStrings.text(
            $r('app.string.image_preview_temp_file_write_failed'),
            'Failed to write temporary file',
          ),
      )
    } finally {
      this.closeFile(file)
    }
  }

  private async copySandboxImageToPhotos(
    filePath: string,
    title: string,
    extension: string,
  ): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)
    const srcFileUri = filePath
    const photoCreationConfigs: photoAccessHelper.PhotoCreationConfig[] = [
      {
        title: title,
        fileNameExtension: extension,
        photoType: photoAccessHelper.PhotoType.IMAGE,
        subtype: photoAccessHelper.PhotoSubtype.DEFAULT,
      },
    ]
    let srcFile: fileIo.File | null = null
    let desFile: fileIo.File | null = null
    try {
      const desFileUris = await phAccessHelper.showAssetsCreationDialog(
        [srcFileUri],
        photoCreationConfigs,
      )
      if (!desFileUris || desFileUris.length === 0) {
        throw new Error(AppStrings.text($r('app.string.image_save_cancelled'), 'Save cancelled'))
      }
      srcFile = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY)
      desFile = await fileIo.open(desFileUris[0], fileIo.OpenMode.WRITE_ONLY)
      await fileIo.copyFile(srcFile.fd, desFile.fd)
    } catch (error) {
      const e = error as Error
      throw new Error(
        e.message ||
          AppStrings.text(
            $r('app.string.image_preview_save_to_gallery_failed'),
            'Failed to save to Gallery',
          ),
      )
    } finally {
      this.closeFile(srcFile)
      this.closeFile(desFile)
    }
  }

  private closeFile(file: fileIo.File | null): void {
    if (!file) {
      return
    }
    try {
      fileIo.closeSync(file)
    } catch (_error) {}
  }

  private removeTempImage(filePath: string): void {
    try {
      fileIo.unlinkSync(filePath)
    } catch (_error) {}
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      // Gesture + image layer. The pinch/pan/double-tap gestures bind to THIS inner layer, not the root
      // Stack, so the overlay back/save buttons (siblings rendered above this layer) receive their own taps —
      // a root-level double-tap/pan otherwise holds or eats the single tap meant for a button.
      Stack() {
        if (!this.normalizedUrl()) {
          Column({ space: ThemeConstants.SPACE_SM }) {
            Text(AppStrings.text($r('app.string.image_preview_url_empty'), 'Image URL is empty'))
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor(Color.White)
            Text(AppStrings.text($r('app.string.image_preview_go_back_retry'), 'Go back and retry'))
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor('#B3B3B3')
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height('100%')
        } else {
          // Single viewport-sized image, transformed about its center. .scale()/.translate() (vp) + renderGroup
          // compose in one layer; never animate width/height (layout props). dismissY rides on the y translate.
          Image(this.normalizedUrl())
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .draggable(false)
            .onComplete((event?: ImagePreviewLoadEvent) => {
              if (event && event.width && event.height) {
                this.intrinsicW = this.getUIContext().px2vp(event.width)
                this.intrinsicH = this.getUIContext().px2vp(event.height)
              }
            })
            .scale({ x: this.scaleValue, y: this.scaleValue })
            .translate({ x: this.offsetX, y: this.offsetY + this.dismissY })
            // Layout-honored offset (separate from the render .translate above): 0 during normal viewing and the
            // live drag; on release-to-dismiss the drag amount is baked here so geometryTransition — which reads
            // the LAYOUT rect, not the render translate — starts the back morph from where the finger let go.
            .offset({ x: 0, y: this.dismissLayoutY })
            .renderGroup(true)
            // Shared-element (Hero) IN node: morphs from the tapped thumbnail's rect. The push/pop sites wrap the
            // route swap in animateTo (animated=false suppresses HDS's default route animation), and THAT animateTo
            // drives this geometryTransition (it has no timing of its own); .transition keeps the node alive across
            // the morph. scale/translate stay at fit (1,0) on entry, so the frame morph is clean.
            .clip(true)
            .geometryTransition(this.heroGid())
            .transition(TransitionEffect.OPACITY)
        }
      }
      .width('100%')
      .height('100%')
      .gesture(
        GestureGroup(
          GestureMode.Parallel,
          PinchGesture({ fingers: 2 })
            .onActionStart((event?: GestureEvent) => {
              if (!event) {
                return
              }
              this.isPinching = true
              this.pinchStartScale = this.scaleValue
              this.pinchStartOffX = this.offsetX
              this.pinchStartOffY = this.offsetY
              this.pinchCenterStartX = event.pinchCenterX as number
              this.pinchCenterStartY = event.pinchCenterY as number
            })
            .onActionUpdate((event?: GestureEvent) => {
              if (!event) {
                return
              }
              const s1: number = this.clampScale(this.pinchStartScale * (event.scale as number))
              const k: number = s1 / this.pinchStartScale
              // Finger-center drift since pinch start contributes a pan; the (1-k) term keeps the start focal
              // point stationary under a center-pivot scale.
              const dx: number = (event.pinchCenterX as number) - this.pinchCenterStartX
              const dy: number = (event.pinchCenterY as number) - this.pinchCenterStartY
              const ox: number =
                (this.pinchCenterStartX - this.viewportWidth / 2) * (1 - k) +
                k * this.pinchStartOffX +
                dx
              const oy: number =
                (this.pinchCenterStartY - this.viewportHeight / 2) * (1 - k) +
                k * this.pinchStartOffY +
                dy
              this.scaleValue = s1
              this.offsetX = this.clampOffsetX(ox, s1)
              this.offsetY = this.clampOffsetY(oy, s1)
            })
            .onActionEnd(() => {
              this.isPinching = false
              this.snapBack()
            })
            .onActionCancel(() => {
              this.isPinching = false
              this.snapBack()
            }),
          PanGesture({ fingers: 1, direction: PanDirection.All })
            .onActionStart(() => {
              this.panStartOffX = this.offsetX
              this.panStartOffY = this.offsetY
            })
            .onActionUpdate((event?: GestureEvent) => {
              if (!event || this.isPinching) {
                return
              }
              if (this.scaleValue > 1.01) {
                this.offsetX = this.clampOffsetX(
                  this.panStartOffX + (event.offsetX as number),
                  this.scaleValue,
                )
                this.offsetY = this.clampOffsetY(
                  this.panStartOffY + (event.offsetY as number),
                  this.scaleValue,
                )
                return
              }
              // At fit: a downward drag arms swipe-to-dismiss; other directions are ignored.
              const dy: number = event.offsetY as number
              if (dy > 0) {
                this.dismissY = dy
                this.backdropAlpha = Math.max(0.3, 1 - dy / 500)
              } else {
                this.dismissY = 0
                this.backdropAlpha = 1
              }
            })
            .onActionEnd((event?: GestureEvent) => {
              if (this.scaleValue > 1.01) {
                return
              }
              this.endDismissGesture(event ? (event.velocityY as number) : 0)
            }),
          TapGesture({ count: 2 }).onAction((event?: GestureEvent) => {
            if (!event) {
              return
            }
            const loc = event.tapLocation
            const tapX: number = loc ? (loc.x as number) : this.viewportWidth / 2
            const tapY: number = loc ? (loc.y as number) : this.viewportHeight / 2
            this.applyDoubleTap(tapX, tapY)
          }),
        ),
      )

      // Floating save control over the image (the HDS title bar is hidden for this route): a white glyph in a
      // dark translucent circle, legible on ANY image. Absolutely positioned at the bottom-right via position()
      // edge anchors, so ONLY this 40x40 button overlays the image — the gesture layer below is untouched and
      // no hit-test passthrough is needed. No explicit back button: swipe-down-to-dismiss and the system back
      // gesture both pop this page. Sibling of the transformed image, so it never pans or zooms with it.
      if (this.normalizedUrl()) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.arrow_down_to_line'))
            .fontSize(22)
            .fontColor([Color.White])
        }
        .width(40)
        .height(40)
        .backgroundColor('#66000000')
        .enabled(!this.isSaving)
        .accessibilityText(AppStrings.text($r('app.string.nav_save_image'), 'Save image'))
        .position({
          right: ThemeConstants.SPACE_MD,
          bottom: this.layout.bottomAvoidHeight + ThemeConstants.SPACE_MD,
        })
        .onClick(() => {
          this.saveImage()
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.backdropColor())
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.viewportWidth = (newValue?.width as number) || 0
      this.viewportHeight = (newValue?.height as number) || 0
    })
  }
}
