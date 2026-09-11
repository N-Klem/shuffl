import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.pinned = false
    this.hover = window.matchMedia("(hover: hover) and (pointer: fine)")
  }

  preview() { if (this.hover.matches) this.setExpanded(true) }
  restore() { this.setExpanded(this.pinned) }
  toggle() {
    this.pinned = !this.pinned
    this.setExpanded(this.pinned)
  }
  close() {
    this.pinned = false
    this.setExpanded(false)
    this.toggleTarget.focus()
  }
  setExpanded(expanded) {
    this.element.classList.toggle("is-expanded", expanded)
    this.toggleTarget.setAttribute("aria-expanded", String(expanded))
  }
}
