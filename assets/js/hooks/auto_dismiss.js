/**
 * AutoDismiss Hook
 *
 * Automatically hides a flash/toast element after 5 seconds.
 * Clears the timer if the element is removed or updated.
 */
const AutoDismiss = {
  mounted() {
    this.timer = setTimeout(() => {
      this.el.style.transition = "opacity 0.3s ease-out, transform 0.3s ease-out"
      this.el.style.opacity = "0"
      this.el.style.transform = "translateX(100%)"
      setTimeout(() => {
        this.el.style.display = "none"
      }, 300)
    }, 5000)
  },

  destroyed() {
    if (this.timer) {
      clearTimeout(this.timer)
    }
  },

  updated() {
    if (this.timer) {
      clearTimeout(this.timer)
    }
    this.mounted()
  }
}

export default AutoDismiss
