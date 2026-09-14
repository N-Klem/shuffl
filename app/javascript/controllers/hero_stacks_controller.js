import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "selector", "status"]

  connect() {
    this.index = 0
    this.show()
  }

  select(event) {
    this.index = Number(event.currentTarget.dataset.index)
    this.show()
  }

  previous() {
    this.index = (this.index - 1 + this.panelTargets.length) % this.panelTargets.length
    this.show()
  }

  next() {
    this.index = (this.index + 1) % this.panelTargets.length
    this.show()
  }

  show() {
    this.panelTargets.forEach((panel, index) => { panel.hidden = index !== this.index })
    this.selectorTargets.forEach((button, index) => {
      button.setAttribute("aria-pressed", String(index === this.index))
    })
    this.statusTarget.textContent = this.panelTargets[this.index].dataset.label
  }
}
