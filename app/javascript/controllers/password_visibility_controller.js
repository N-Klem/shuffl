import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "toggle"]

  toggle() {
    const visible = this.inputTarget.type === "password"
    this.inputTarget.type = visible ? "text" : "password"
    this.toggleTarget.textContent = visible ? "hide" : "show"
    this.toggleTarget.setAttribute("aria-label", visible ? "Hide password" : "Show password")
    this.toggleTarget.setAttribute("aria-pressed", visible)
  }
}
