import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.sync()

    // Follow the operating system while the visitor has not chosen for themselves,
    // so switching the OS to dark at night changes the page under them rather than
    // leaving them on whatever the theme happened to be when they first loaded it.
    if (window.matchMedia) {
      this.osTheme = matchMedia("(prefers-color-scheme: dark)")
      this.followOs = event => {
        if (this.storedChoice()) return
        const theme = event.matches ? "dark" : "light"
        document.documentElement.dataset.theme = theme
        document.documentElement.dataset.bsTheme = theme
        this.sync()
      }
      this.osTheme.addEventListener("change", this.followOs)
    }
  }

  disconnect() {
    if (this.osTheme) this.osTheme.removeEventListener("change", this.followOs)
  }

  storedChoice() {
    try {
      const v = localStorage.getItem("shuffl-theme")
      return v === "dark" || v === "light" ? v : null
    } catch (_) {
      return null
    }
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
