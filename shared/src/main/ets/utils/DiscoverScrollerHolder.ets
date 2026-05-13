/**
 * Shared scroller holder for DiscoverPage to communicate with Index.ets
 * Avoids @Provide/@Consume type restrictions on Scroller objects.
 */
export class DiscoverScrollerHolder {
  static scroller: Scroller = new Scroller()
}
