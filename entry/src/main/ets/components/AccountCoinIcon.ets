@ComponentV2
export struct AccountCoinIcon {
  @Param rimColor: string = ''
  @Param faceColor: string = ''
  @Param edgeColor: string = ''
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)

  build() {
    Canvas(this.context)
      .width(16)
      .height(16)
      .onReady(() => {
        this.drawCoin()
      })
  }

  private drawCoin(): void {
    const ctx = this.context
    ctx.clearRect(0, 0, 16, 16)
    const face = ctx.createLinearGradient(3, 2, 13, 14)
    face.addColorStop(0.0, this.faceColor)
    face.addColorStop(0.62, this.edgeColor)
    face.addColorStop(1.0, this.rimColor)
    ctx.beginPath()
    ctx.arc(8, 8, 7.2, 0, Math.PI * 2)
    ctx.fillStyle = this.rimColor
    ctx.fill()
    ctx.save()
    ctx.beginPath()
    ctx.arc(8, 8, 5.8, 0, Math.PI * 2)
    ctx.clip()
    ctx.fillStyle = face
    ctx.fillRect(2, 2, 12, 12)
    ctx.fillStyle = 'rgba(0,0,0,0.10)'
    ctx.beginPath()
    ctx.moveTo(2.2, 10.8)
    ctx.quadraticCurveTo(8.0, 13.8, 13.8, 10.8)
    ctx.lineTo(13.8, 14.2)
    ctx.lineTo(2.2, 14.2)
    ctx.closePath()
    ctx.fill()
    ctx.restore()
    ctx.beginPath()
    ctx.arc(8, 8, 5.8, 0, Math.PI * 2)
    ctx.lineWidth = 1
    ctx.strokeStyle = 'rgba(255,255,255,0.42)'
    ctx.stroke()
    ctx.beginPath()
    ctx.arc(8, 8, 6.9, 0, Math.PI * 2)
    ctx.lineWidth = 1.2
    ctx.strokeStyle = this.rimColor
    ctx.stroke()
  }
}
