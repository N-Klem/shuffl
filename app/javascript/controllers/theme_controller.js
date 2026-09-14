import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.sync()
  }

  toggle() {
    const theme = document.documentElement.dataset.theme === "dark" ? "light" : "dark"
    document.documentElement.dataset.theme = theme
    document.documentElement.dataset.bsTheme = theme
    try { localStorage.setItem("shuffl-theme", theme) } catch (_) { /* Storage may be unavailable. */ }
    this.sync()
  }

  sync() {
    const dark = document.documentElement.dataset.theme === "dark"
    this.element.setAttribute("aria-pressed", String(dark))
    this.element.setAttribute("aria-label", dark ? "Switch to light mode" : "Switch to dark mode")
    this.element.title = dark ? "Switch to light mode" : "Switch to dark mode"
  }
}
