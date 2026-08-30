/**
 * GallerySwipe — keeps a product gallery's swipe position and its selected
 * thumbnail in agreement.
 *
 * The gallery is a native scroll-snap strip, so swiping on a phone is the
 * browser's own gesture: no touch handlers, no momentum maths, and it works
 * with a trackpad, a mouse wheel and a keyboard too. This hook only carries
 * the selection across the two directions the browser cannot:
 *
 *   thumbnail clicked -> server sets data-current -> scroll the strip there
 *   strip swiped      -> settle on a slide        -> tell the server
 *
 * The guard on both sides is the same comparison, so the two never chase each
 * other in a loop.
 */
const GallerySwipe = {
  mounted() {
    this.settled = true
    this.syncFromServer(false)

    let timer
    this.el.addEventListener(
      "scroll",
      () => {
        clearTimeout(timer)
        // Wait for the swipe to settle: scroll fires continuously, and a
        // push per frame would flood the socket on a slow connection.
        timer = setTimeout(() => this.pushIndex(), 140)
      },
      { passive: true },
    )
  },

  updated() {
    this.syncFromServer(true)
  },

  // Scroll to whatever the server says is current. Jump on mount (the page is
  // still assembling); glide afterwards, since by then it is a user action.
  syncFromServer(animate) {
    const index = this.currentIndex()
    const slide = this.el.children[index]
    if (!slide) return

    if (Math.abs(this.el.scrollLeft - slide.offsetLeft) > 4) {
      this.el.scrollTo({
        left: slide.offsetLeft,
        behavior: animate && !this.prefersReducedMotion() ? "smooth" : "auto",
      })
    }
  },

  pushIndex() {
    const width = this.el.clientWidth
    if (width === 0) return

    const index = Math.round(this.el.scrollLeft / width)
    if (index === this.currentIndex()) return

    // Same event and payload shape the thumbnails send, so a theme needs only
    // its existing handle_event("select_image", %{"index" => _}).
    this.pushEvent("select_image", { index: String(index) })
  },

  currentIndex() {
    return parseInt(this.el.dataset.current || "0", 10) || 0
  },

  prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  },
}

export default GallerySwipe
