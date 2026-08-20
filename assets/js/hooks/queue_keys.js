// j/k queue navigation for admin review pages. Pushes "queue_key" to the
// LiveView, but never while the user is typing in a form field.
const QueueKeys = {
  mounted(){
    this.onKey = (e) => {
      if(e.metaKey || e.ctrlKey || e.altKey) return
      if(e.key !== "j" && e.key !== "k") return
      const t = e.target
      if(t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.tagName === "SELECT" || t.isContentEditable)) return
      e.preventDefault()
      this.pushEvent("queue_key", {key: e.key})
    }
    window.addEventListener("keydown", this.onKey)
  },
  destroyed(){
    window.removeEventListener("keydown", this.onKey)
  }
}

export default QueueKeys
