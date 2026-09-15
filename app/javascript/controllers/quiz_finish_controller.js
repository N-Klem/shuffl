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

    // Sweep a gently rippling edge left to right. The drawn dot is part of the
    // same wordmark, so it fills last and completion reveals the results.
    const frames = Array.from({ length: 81 }, (_, index) => {
      const progress = index / 80
      const front = -8 + progress * 116
      const edge = Array.from({ length: 17 }, (_, point) => {
        const y = point / 16
        const x = front + Math.sin(y * Math.PI * 2 + progress * Math.PI * 6) * 3
        return `${x}% ${y * 100}%`
      })
      return { clipPath: `polygon(-12% 0%, ${edge.join(", ")}, -12% 100%)`, offset: progress }
    })
    this.fill = this.overlay.querySelector(".finish-wordmark-fill").animate(frames, {
      duration: 5000, easing: "linear", fill: "forwards"
    })
    this.fill.finished.then(() => this.revealResults()).catch(() => {})
  }

  revealResults() {
    this.overlay?.remove()
    this.element.inert = false
    this.element.querySelectorAll(".recommendation").forEach((card, i) => {
      card.animate([{ opacity: 0, transform: "translateY(18px)" }, { opacity: 1, transform: "translateY(0)" }], {
        duration: 420, delay: i * 70, fill: "backwards", easing: "cubic-bezier(.23,1,.32,1)"
      })
    })
  }

  disconnect() {
    this.fill?.cancel()
    this.overlay?.remove()
    this.element.inert = false
  }
}
