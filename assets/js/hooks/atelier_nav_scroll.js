// AtelierNavScroll — toggles transparent navbar to solid on scroll
const AtelierNavScroll = {
  mounted() {
    this.nav = document.getElementById(this.el.dataset.navId)
    if (!this.nav) return

    this.onScroll = () => {
      if (window.scrollY > 60) {
        this.nav.classList.add("atelier-nav-scrolled")
        this.nav.classList.remove("atelier-nav-transparent")
      } else {
        this.nav.classList.remove("atelier-nav-scrolled")
        this.nav.classList.add("atelier-nav-transparent")
      }
    }

    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.onScroll()
  },

  destroyed() {
    if (this.onScroll) {
      window.removeEventListener("scroll", this.onScroll)
    }
  }
}

export default AtelierNavScroll
