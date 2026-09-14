import { Controller } from "@hotwired/stimulus"

// Featured-stack carousel. Each switch deals the incoming stack in — the card
// motion the product is named for. The outgoing panel is hidden at once (as it
// always was), so rapid clicks and reduced motion stay clean by construction;
// only the entrance animates.
export default class extends Controller {
  static targets = ["panel", "selector", "status"]

  connect() {
    this.index = 0
    this.motion = matchMedia("(prefers-reduced-motion: reduce)")
    this.reveal()
  }

  select(event) { this.go(Number(event.currentTarget.dataset.index)) }
  next()        { this.go((this.index + 1) % this.panelTargets.length) }
  previous()    { this.go((this.index - 1 + this.panelTargets.length) % this.panelTargets.length) }

  go(target) {
    const next = this.panelTargets[target]
    if (target === this.index && next && !next.hidden) return
    const dir = this.direction(this.index, target)
    this.index = target
    this.show(dir)
  }

  // Shortest way round the ring, so the deal slides the way the dots move.
  direction(from, to) {
    const n = this.panelTargets.length
    let d = to - from
    if (d >  n / 2) d -= n
    if (d < -n / 2) d += n
    return d < 0 ? -1 : 1
  }

  show(dir) {
    const next = this.panelTargets[this.index]
    this.reveal()
    this.panelTargets.forEach(panel => { panel.hidden = panel !== next })
    if (this.motion.matches) return
    this.deal?.cancel()
    this.deal = next.animate(
      [{ transform: `translateX(${34 * dir}px) rotate(${3 * dir}deg) scale(.96)`, opacity: 0 },
       { transform: "translateX(0) rotate(0deg) scale(1)", opacity: 1 }],
      { duration: 460, easing: "cubic-bezier(.22,.61,.36,1)" }
    )
  }

  reveal() {
    this.selectorTargets.forEach((button, i) => button.setAttribute("aria-pressed", String(i === this.index)))
    if (this.hasStatusTarget) this.statusTarget.textContent = this.panelTargets[this.index].dataset.label || ""
  }

  disconnect() { this.deal?.cancel() }
}
