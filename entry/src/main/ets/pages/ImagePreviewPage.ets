import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { fileIo } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { http } from '@kit.NetworkKit'
import { MediaUrlUtils, StorageKeys, ThemeConstants } from 'shared'
import { ImagePreviewCoordinator } from '../model/ImagePreviewCoordinator'

const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 30000

interface ImageDownloadResult {
  buffer: ArrayBuffer
  contentType: string
}

@Component
export struct ImagePreviewPage {
  @Consume('ns') stack: NavPathStack
  @Prop url: string = ''

  @State private viewportWidth: number = 0
  @State private scaleValue: number = 1
  @State private pinchValue: number = 1
  @State private isSaving: boolean = false
  @State private saveMessage: string = ''
  @StorageLink(StorageKeys.IMAGE_PREVIEW_ACTION) @Watch('onImagePreviewActionCommand') imagePreviewActionCommand: string = ''
  @StorageProp('topAvoidHeight') topH: number = 0

  private clampScale(value: number): number {
    return ImagePreviewCoordinator.clampScale(value)
  }

  private getImageWidth(): number | string {
    return ImagePreviewCoordinator.imageWidth(this.viewportWidth, this.scaleValue)
  }

  private normalizedUrl(): string {
    return MediaUrlUtils.normalizeUrl(this.url)
  }

  private onImagePreviewActionCommand(_propName: string): void {
    if (ImagePreviewCoordinator.actionFromCommand(this.imagePreviewActionCommand) === 'save') {
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
      this.showToast('图片地址无效')
      return
    }

    let tempPath = ''
    this.isSaving = true
    this.saveMessage = '正在下载图片'
    try {
      const result = await this.downloadImage(imageUrl)
      if (result.contentType && result.contentType.toLowerCase().indexOf('image/') !== 0) {
        throw new Error('该链接返回的不是图片')
      }
      const extension = MediaUrlUtils.preferredImageExtension(imageUrl, result.contentType)
      const title = MediaUrlUtils.imageTitleFromUrl(imageUrl)
      tempPath = this.writeTempImage(result.buffer, extension)

      this.saveMessage = '请选择保存位置'
      await this.copySandboxImageToPhotos(tempPath, title, extension)
      this.showToast('已保存到图库')
    } catch (error) {
      const e = error as Error
      this.showToast(e.message || '保存失败')
    } finally {
      if (tempPath) {
        this.removeTempImage(tempPath)
      }
      this.isSaving = false
      this.saveMessage = ''
    }
  }

  private async downloadImage(imageUrl: string): Promise<ImageDownloadResult> {
    let httpRequest = http.createHttp()
    let headerBag: Object | null = null
    httpRequest.on('headersReceive', (headers: Object) => {
      headerBag = headers
    })

    try {
      const response = await httpRequest.request(imageUrl, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'image/avif,image/webp,image/png,image/svg+xml,image/*,*/*;q=0.8',
          'Accept-Encoding': 'gzip',
          'User-Agent': 'Mozilla/5.0'
        },
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: false,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
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
      throw new Error(e.message || '图片下载失败')
    } finally {
      httpRequest.destroy()
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
      throw new Error(e.message || '临时文件写入失败')
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
        throw new Error('已取消保存')
      }
      srcFile = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY)
      desFile = await fileIo.open(desFileUris[0], fileIo.OpenMode.WRITE_ONLY)
      await fileIo.copyFile(srcFile.fd, desFile.fd)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存到图库失败')
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
            Text('图片地址为空')
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor(Color.White)
            Text('返回后重试')
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
          top: this.topH + ThemeConstants.TITLE_BAR_HEIGHT + ThemeConstants.SPACE_MD,
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
