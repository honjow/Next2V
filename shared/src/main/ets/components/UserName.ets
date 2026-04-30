@Component
export struct UserName {
  @Prop username: string = ''
  @Prop fontSize: number = 14

  build() {
    Text(this.username)
      .fontSize(this.fontSize)
      .fontColor($r('sys.color.font_primary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
}
