/**
 * ScrollGlass Hook — Toggles `.scrolled` class on a nav element
 * when the page scrolls past a threshold (40px).
 *
 * Usage: <nav id="main-nav" phx-hook="ScrollGlass">
 */
const ScrollGlass = {
  mounted() {
    this.threshold = parseInt(this.el.dataset.scrollThreshold || "40", 10)
    this.onScroll = () => {
      if (window.scrollY > this.threshold) {
        this.el.classList.add("scrolled")
      } else {
        this.el.classList.remove("scrolled")
      }
    }
    window.addEventListener("scroll", this.onScroll, { passive: true })
    // Check initial state
    this.onScroll()
  },

  destroyed() {
    window.removeEventListener("scroll", this.onScroll)
  }
}

export default ScrollGlass
