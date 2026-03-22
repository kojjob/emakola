/**
 * AddToBag Hook — Micro-interaction for "Add to Bag" buttons.
 * Shows "Added!" text with green background for 1.6s, then reverts.
 *
 * Usage: <button phx-hook="AddToBag" phx-click="add_to_cart" data-original-text="Add to Bag">
 */
const AddToBag = {
  mounted() {
    this.originalText = this.el.dataset.originalText || this.el.textContent.trim()
    this.originalBg = this.el.dataset.originalBg || ""
    this.timeout = null

    this.handleEvent("item_added", () => {
      this.showFeedback()
    })
  },

  showFeedback() {
    if (this.timeout) clearTimeout(this.timeout)

    // Save current state
    const el = this.el

    // Switch to "Added!" state
    el.textContent = "Added!"
    el.classList.add("bg-emerald-600", "border-emerald-600", "text-white", "scale-95")
    el.classList.remove("bg-[#1C1917]", "bg-stone-900", "hover:bg-stone-800")

    this.timeout = setTimeout(() => {
      el.textContent = this.originalText
      el.classList.remove("bg-emerald-600", "border-emerald-600", "scale-95")
      el.classList.add("bg-[#1C1917]", "bg-stone-900")
      this.timeout = null
    }, 1600)
  },

  destroyed() {
    if (this.timeout) clearTimeout(this.timeout)
  }
}

export default AddToBag
