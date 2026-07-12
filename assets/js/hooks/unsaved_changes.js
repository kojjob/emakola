/**
 * UnsavedChanges Hook
 *
 * Warns before leaving the editor while it holds unpublished changes, on
 * both exit paths:
 *
 *   1. beforeunload — tab close, hard navigation, Back.
 *   2. capture-phase click on live_redirect/live_patch anchors — in-app
 *      navigation (e.g. a sidebar link), which never fires beforeunload.
 *
 * The dirty flag is read fresh from the element's `data-dirty` attribute
 * inside each handler, so LiveView re-rendering the attribute is all the
 * wiring `updated()` would otherwise need.
 */
const UnsavedChanges = {
  mounted() {
    this.onBeforeUnload = (event) => {
      if (this.el.dataset.dirty === "true") {
        event.preventDefault()
        // Legacy browsers require returnValue to be set to show the prompt.
        event.returnValue = ""
      }
    }
    window.addEventListener("beforeunload", this.onBeforeUnload)

    // Capture phase (the `true` third arg) is REQUIRED: LiveView binds its
    // own document-level click handler for live_redirect/live_patch anchors,
    // so we must see the event on the way DOWN the tree to cancel it before
    // LiveView acts on it. A bubble-phase listener would fire too late —
    // the navigation would already be underway.
    this.onNavClick = (event) => {
      if (this.el.dataset.dirty !== "true") return

      const link = event.target.closest("a[data-phx-link]")
      // Not a live-nav link, or a live-nav link inside the editor itself
      // (not an exit) — let it through.
      if (!link || this.el.contains(link)) return

      const leave = window.confirm(
        "You have unsaved section changes. Leave without publishing?"
      )
      if (!leave) {
        event.preventDefault()
        event.stopPropagation()
      }
    }
    document.addEventListener("click", this.onNavClick, true)
  },

  destroyed() {
    window.removeEventListener("beforeunload", this.onBeforeUnload)
    document.removeEventListener("click", this.onNavClick, true)
  }
}

export default UnsavedChanges
