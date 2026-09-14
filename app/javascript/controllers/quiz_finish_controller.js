import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static values = { enabled: Boolean }
  connect() {
    if (!this.enabledValue || matchMedia("(prefers-reduced-motion: reduce)").matches) return
    this.enabledValue = false
    const template = document.getElementById("quiz-finish-template")
    if (!template) return
    this.overlay = template.content.firstElementChild.cloneNode(true)
    document.body.append(this.overlay)
    this.element.inert = true
    this.timer = setTimeout(() => {
      this.overlay?.remove()
      this.element.inert = false
      this.element.querySelectorAll('.recommendation').forEach((card, i) => {
        card.animate([{ opacity: 0, transform: 'translateY(18px)' }, { opacity: 1, transform: 'translateY(0)' }], { duration: 420, delay: i * 70, fill: 'backwards', easing: 'cubic-bezier(.23,1,.32,1)' })
      })
    }, 5000)
  }
  disconnect() { clearTimeout(this.timer); this.overlay?.remove(); this.element.inert = false }
}
