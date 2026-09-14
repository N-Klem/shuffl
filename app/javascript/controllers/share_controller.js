import { Controller } from "@hotwired/stimulus"

// Hands the current page to the native share sheet where there is one (phones),
// otherwise copies the link to the clipboard.
export default class extends Controller {
  static targets = ["status"]
  static values = { title: String }

  async share() {
    const url = window.location.href
    try {
      if (navigator.share) {
        await navigator.share({ title: this.titleValue, url })
        this.say("Shared.")
      } else {
        await navigator.clipboard.writeText(url)
        this.say("Link copied.")
      }
    } catch (error) {
      if (error.name === "AbortError") return
      this.say(`Copy this link: ${url}`)
    }
  }

  say(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
