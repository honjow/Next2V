import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { fileIo } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { http } from '@kit.NetworkKit'
import {
  AppStrings, connectImagePreviewAction, connectLayoutSafeArea, connectNavStack, ImagePreviewActionState,
  LayoutSafeAreaState, MediaUrlUtils, NetworkProxyRequest, ThemeConstants
} from 'shared'
import { ImagePreviewCoordinator } from '../model/ImagePreviewCoordinator'

const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 30000

interface ImageDownloadResult {
  buffer: ArrayBuffer
  contentType: string
}

@ComponentV2
export struct ImagePreviewPage {
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder); method target only.
  private stack: NavPathStack = connectNavStack().stack
  @Param url: string = ''

  @Local private viewportWidth: number = 0
  @Local private scaleValue: number = 1
  @Local private pinchValue: number = 1
  @Local private isSaving: boolean = false
  @Local private saveMessage: string = ''
  // V2 mirror of the one-directional IMAGE_PREVIEW_ACTION appbar command (Index dual-writes).
  @Local private imgAction: ImagePreviewActionState = connectImagePreviewAction()
  // Window safe-area metrics (V2 mirror; EntryAbility dual-writes the V1 AppStorage keys + this).
  private layout: LayoutSafeAreaState = connectLayoutSafeArea()

  private clampScale(value: number): number {
    return ImagePreviewCoordinator.clampScale(value)
  }

  private getImageWidth(): number | string {
    return ImagePreviewCoordinator.imageWidth(this.viewportWidth, this.scaleValue)
  }

  private normalizedUrl(): string {
    return MediaUrlUtils.normalizeUrl(this.url)
  }

  @Monitor('imgAction.command')
  private onImagePreviewActionCommand(): void {
    if (ImagePreviewCoordinator.actionFromCommand(this.imgAction.command) === 'save') {
      this.saveImage()
    }
  }

  private showToast(message: string): void {
    promptAction.openToast({ message: message }).catch((_error: Error) => { })
  }

  private async saveImage(): Promise<void> {
    if (this.isSaving) {
      return
    }
    const imageUrl = this.normalizedUrl()
    if (!MediaUrlUtils.isHttpUrl(imageUrl)) {
      this.showToast(AppStrings.text($r('app.string.image_preview_invalid_url'), 'Invalid image URL'))
      return
    }

    let tempPath = ''
    this.isSaving = true
    this.saveMessage = AppStrings.text($r('app.string.image_preview_downloading'), 'Downloading image\u2026')
    try {
      const result = await this.downloadImage(imageUrl)
      if (result.contentType && result.contentType.toLowerCase().indexOf('image/') !== 0) {
        throw new Error(AppStrings.text($r('app.string.image_preview_not_an_image'), 'The link did not return an image'))
      }
      const extension = MediaUrlUtils.preferredImageExtension(imageUrl, result.contentType)
      const title = MediaUrlUtils.imageTitleFromUrl(imageUrl)
      tempPath = this.writeTempImage(result.buffer, extension)

      this.saveMessage = AppStrings.text($r('app.string.image_preview_choose_save_location'), 'Please choose a save location')
      await this.copySandboxImageToPhotos(tempPath, title, extension)
      this.showToast(AppStrings.text($r('app.string.image_saved_to_gallery'), 'Saved to Gallery'))
    } catch (error) {
      const e = error as Error
      this.showToast(e.message || AppStrings.text($r('app.string.image_preview_save_failed'), 'Save failed'))
    } finally {
      if (tempPath) {
        this.removeTempImage(tempPath)
      }
      this.isSaving = false
      this.saveMessage = ''
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
          'User-Agent': 'Mozilla/5.0'
        },
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: false,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        onHeadersReceive: (headers: Object) => { headerBag = headers }
      })
      const statusCode = response.responseCode as number
      if (statusCode < 200 || statusCode >= 300) {
        throw new Error(`HTTP ${statusCode}`)
      }
      return {
        buffer: response.result as ArrayBuffer,
        contentType: ImagePreviewCoordinator.extractHeaderValue(headerBag || response.header, 'content-type')
      }
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || AppStrings.text($r('app.string.image_preview_download_failed'), 'Image download failed'))
    }
  }

  private writeTempImage(buffer: ArrayBuffer, extension: string): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const filePath = `${context.filesDir}/v2next_image_${Date.now()}.${extension}`
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      fileIo.writeSync(file.fd, buffer)
      return filePath
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || AppStrings.text($r('app.string.image_preview_temp_file_write_failed'), 'Failed to write temporary file'))
    } finally {
      this.closeFile(file)
    }
  }

  private async copySandboxImageToPhotos(filePath: string, title: string, extension: string): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)
    const srcFileUri = filePath
    const photoCreationConfigs: photoAccessHelper.PhotoCreationConfig[] = [
      {
        title: title,
        fileNameExtension: extension,
        photoType: photoAccessHelper.PhotoType.IMAGE,
        subtype: photoAccessHelper.PhotoSubtype.DEFAULT
      }
    ]
    let srcFile: fileIo.File | null = null
    let desFile: fileIo.File | null = null
    try {
      const desFileUris = await phAccessHelper.showAssetsCreationDialog([srcFileUri], photoCreationConfigs)
      if (!desFileUris || desFileUris.length === 0) {
        throw new Error(AppStrings.text($r('app.string.image_save_cancelled'), 'Save cancelled'))
      }
      srcFile = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY)
      desFile = await fileIo.open(desFileUris[0], fileIo.OpenMode.WRITE_ONLY)
      await fileIo.copyFile(srcFile.fd, desFile.fd)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || AppStrings.text($r('app.string.image_preview_save_to_gallery_failed'), 'Failed to save to Gallery'))
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
    } catch (_error) {
    }
  }

  private removeTempImage(filePath: string): void {
    try {
      fileIo.unlinkSync(filePath)
    } catch (_error) {
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
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
          .layoutWeight(1)
        } else {
          Scroll() {
            Scroll() {
              Image(this.normalizedUrl())
                .width(this.getImageWidth())
                .objectFit(ImageFit.Contain)
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
          }
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Off)
          .width('100%')
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')

      if (this.normalizedUrl() && this.saveMessage) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(this.saveMessage)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor('#D9FFFFFF')
            .padding({
              left: ThemeConstants.SPACE_SM,
              right: ThemeConstants.SPACE_SM,
              top: ThemeConstants.SPACE_XS,
              bottom: ThemeConstants.SPACE_XS
            })
            .borderRadius(ThemeConstants.RADIUS_SM)
            .backgroundColor('#66000000')
        }
        .alignItems(HorizontalAlign.End)
        .padding({
          top: this.layout.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT + ThemeConstants.SPACE_MD,
          right: ThemeConstants.SPACE_MD,
          left: ThemeConstants.SPACE_MD
        })
      }
    }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.viewportWidth = (newValue?.width as number) || 0
      })
      .parallelGesture(
        PinchGesture({ fingers: 2 })
          .onActionStart(() => {
            this.pinchValue = this.scaleValue
          })
          .onActionUpdate((event?: GestureEvent) => {
            if (!event) {
              return
            }
            this.scaleValue = this.clampScale(this.pinchValue * (event.scale as number))
          })
          .onActionEnd(() => {
            this.pinchValue = this.scaleValue
          })
      )
  }
}
