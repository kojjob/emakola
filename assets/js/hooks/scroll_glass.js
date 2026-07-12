/**
 * ScrollGlass — Toggles `.scrolled` class on a nav element when the page
 * scrolls past a threshold (40px).
 *
 * Two entry points share bindScrollGlass:
 *  - LiveView hook:  <nav phx-hook="ScrollGlass">
 *  - Dead pages:     <nav data-scroll-glass> (bound by app.js)
 */
export function bindScrollGlass(el) {
  const threshold = parseInt(el.dataset.scrollThreshold || "40", 10)
  const onScroll = () => {
    if (window.scrollY > threshold) {
      el.classList.add("scrolled")
    } else {
      el.classList.remove("scrolled")
    }
  }
  window.addEventListener("scroll", onScroll, { passive: true })
  // Check initial state
  onScroll()
  return onScroll
}

const ScrollGlass = {
  mounted() {
    this.onScroll = bindScrollGlass(this.el)
  },

  destroyed() {
    window.removeEventListener("scroll", this.onScroll)
  }
}

export default ScrollGlass
