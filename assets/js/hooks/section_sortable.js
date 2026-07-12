/**
 * SectionSortable Hook
 *
 * Hand-rolled HTML5 drag-and-drop reordering for the section-editor rail —
 * no drag library (spec-verbatim: no SortableJS). Rows carry `draggable`
 * and `data-section-id`; this hook listens on the rows container itself
 * (event delegation), so rows added/removed by LiveView patches need no
 * re-binding.
 *
 * On drop it pushes ONE `reorder` event with the full post-drop id order.
 * The hook never rewrites the DOM itself — the actual reflow comes back as
 * an ordinary LiveView diff once the server applies the reorder.
 */
const ROW_SELECTOR = "[data-section-id]"
const DROP_ABOVE = "section-drop-above"
const DROP_BELOW = "section-drop-below"

const SectionSortable = {
  mounted() {
    this.draggedId = null
    this.dropSide = "below"
    this.indicatorRow = null

    this.onDragStart = (event) => {
      const row = event.target.closest(ROW_SELECTOR)
      if (!row) return
      this.draggedId = row.dataset.sectionId
      event.dataTransfer.effectAllowed = "move"
      // Firefox refuses to start a drag at all unless data is set.
      event.dataTransfer.setData("text/plain", this.draggedId)
    }

    this.onDragOver = (event) => {
      if (!this.draggedId) return
      const row = event.target.closest(ROW_SELECTOR)
      if (!row || row.dataset.sectionId === this.draggedId) return

      // Required so the browser fires `drop` instead of rejecting it.
      event.preventDefault()
      event.dataTransfer.dropEffect = "move"

      const above = event.clientY < row.getBoundingClientRect().top + row.offsetHeight / 2
      this.setIndicator(row, above ? "above" : "below")
    }

    this.onDrop = (event) => {
      if (!this.draggedId) return
      const row = event.target.closest(ROW_SELECTOR)
      event.preventDefault()

      if (row && row.dataset.sectionId !== this.draggedId) {
        this.pushEvent("reorder", {order: this.newOrder(row)})
      }

      this.draggedId = null
      this.clearIndicator()
    }

    this.onDragEnd = () => {
      this.draggedId = null
      this.clearIndicator()
    }

    this.el.addEventListener("dragstart", this.onDragStart)
    this.el.addEventListener("dragover", this.onDragOver)
    this.el.addEventListener("drop", this.onDrop)
    this.el.addEventListener("dragend", this.onDragEnd)
  },

  // Current DOM order with the dragged id removed and reinserted next to
  // `targetRow`, on the side of the last drop indicator. The DOM itself is
  // left untouched — the server-rendered diff after `reorder` does the
  // actual reflow.
  newOrder(targetRow) {
    const ids = Array.from(this.el.querySelectorAll(ROW_SELECTOR)).map((row) => row.dataset.sectionId)
    const from = ids.indexOf(this.draggedId)
    if (from === -1) return ids

    ids.splice(from, 1)
    let to = ids.indexOf(targetRow.dataset.sectionId)
    if (this.dropSide === "below") to += 1
    ids.splice(to, 0, this.draggedId)
    return ids
  },

  setIndicator(row, side) {
    if (this.indicatorRow === row && this.dropSide === side) return
    this.clearIndicator()
    row.classList.add(side === "above" ? DROP_ABOVE : DROP_BELOW)
    this.indicatorRow = row
    this.dropSide = side
  },

  clearIndicator() {
    if (this.indicatorRow) {
      this.indicatorRow.classList.remove(DROP_ABOVE, DROP_BELOW)
      this.indicatorRow = null
    }
  },

  destroyed() {
    this.el.removeEventListener("dragstart", this.onDragStart)
    this.el.removeEventListener("dragover", this.onDragOver)
    this.el.removeEventListener("drop", this.onDrop)
    this.el.removeEventListener("dragend", this.onDragEnd)
    this.clearIndicator()
  }
}

export default SectionSortable
