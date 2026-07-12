/**
 * UnsavedChanges Hook
 *
 * Warns before the tab is closed or navigated away while the editor holds
 * unpublished changes. The dirty flag is read fresh from the element's
 * `data-dirty` attribute inside the handler, so LiveView re-rendering the
 * attribute is all the wiring `updated()` would otherwise need.
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
  },

  destroyed() {
    window.removeEventListener("beforeunload", this.onBeforeUnload)
  }
}

export default UnsavedChanges
