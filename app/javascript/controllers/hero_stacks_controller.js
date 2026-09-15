import { Controller } from "@hotwired/stimulus"

// A readable four-beat deal: gather, leave, arrive, fan. Keep only the latest
// requested destination while dealing, rather than building a queue of clicks.
export default class extends Controller {
  static targets = ["panel", "selector", "status"]

  connect() {
    this.index = 0
    this.requested = 0
    this.animations = new Set()
    this.motion = matchMedia("(prefers-reduced-motion: reduce)")
    const style = getComputedStyle(this.element)
    this.ease = style.getPropertyValue("--ease-out").trim() || "cubic-bezier(0.23, 1, 0.32, 1)"
    this.morph = style.getPropertyValue("--ease-in-out").trim() || "cubic-bezier(0.77, 0, 0.175, 1)"
    this.reveal()
  }

  select(event) { this.go(Number(event.currentTarget.dataset.index)) }
  next() { this.go((this.requested + 1) % this.panelTargets.length, 1) }
  previous() { this.go((this.requested - 1 + this.panelTargets.length) % this.panelTargets.length, -1) }

  async go(target, direction = null) {
    if (!this.panelTargets[target]) return
    this.requested = target
    // Arrow direction stays consistent across the last/first boundary.
    // Direct selectors follow their left-to-right position in the rail.
    this.requestedDirection = direction
    if (this.busy) return
    this.busy = true
    try {
      while (this.index !== this.requested && this.element.isConnected) {
        await this.deal(this.requested, this.requestedDirection ?? Math.sign(this.requested - this.index))
      }
    } finally {
      this.busy = false
    }
  }

  cards(panel) { return [...panel.querySelectorAll(".fan-card, .ghost-card")] }

  async animate(element, frames, duration, easing = this.ease) {
    const animation = element.animate(frames, { duration, easing, fill: "forwards" })
    this.animations.add(animation)
    await animation.finished
  }

  clearAnimations() {
    this.animations.forEach(animation => animation.cancel())
    this.animations.clear()
  }

  async deal(target, direction) {
    const outgoing = this.panelTargets[this.index]
    const incoming = this.panelTargets[target]
    const cards = this.cards(outgoing)
    const starts = cards.map(card => ({ transform: getComputedStyle(card).transform, opacity: getComputedStyle(card).opacity }))
    const collapsed = { transform: "translate(0, 0) rotate(0deg)", opacity: 1 }
    this.element.classList.add("is-dealing")
    this.panelTargets.forEach(panel => {
      panel.inert = true
      panel.querySelector(".stack-tile")?.dispatchEvent(new Event("stack:reset"))
    })
    try {
      if (!this.motion.matches) {
        await Promise.all(cards.map((card, i) => this.animate(card, [starts[i], collapsed], 260, this.morph)))
        const art = outgoing.querySelector(".stack-fan, .ghost-stack")
        if (art) await this.animate(art, [{ transform: "translateX(0)", opacity: 1 }, { transform: `translateX(${-85 * direction}%)`, opacity: 0 }], 380)
      }
      outgoing.hidden = true
      incoming.hidden = false
      this.index = target
      this.reveal()
      if (this.motion.matches) {
        await this.animate(incoming, [{ opacity: 0 }, { opacity: 1 }], 150)
      } else {
        const nextCards = this.cards(incoming)
        const rests = nextCards.map(card => ({ transform: getComputedStyle(card).transform, opacity: getComputedStyle(card).opacity }))
        // Hold the new cards together during travel, then release into the fan.
        const holds = nextCards.map(card => {
          const hold = card.animate([collapsed, collapsed], { duration: 1, fill: "forwards" })
          this.animations.add(hold)
          return hold
        })
        const art = incoming.querySelector(".stack-fan, .ghost-stack")
        if (art) await this.animate(art, [{ transform: `translateX(${85 * direction}%)`, opacity: 0 }, { transform: "translateX(0)", opacity: 1 }], 400)
        holds.forEach(hold => { hold.cancel(); this.animations.delete(hold) })
        await Promise.all(nextCards.map((card, i) => this.animate(card, [collapsed, rests[i]], 300, this.morph)))
      }
    } catch (error) {
      if (error.name !== "AbortError") throw error
    } finally {
      this.clearAnimations()
      this.panelTargets.forEach((panel, i) => { panel.hidden = i !== this.index; panel.inert = false })
      this.element.classList.remove("is-dealing")
      this.panelTargets[this.index].querySelector(".stack-tile")?.dispatchEvent(new Event("stack:rest"))
    }
  }

  reveal() {
    this.panelTargets.forEach((panel, i) => { panel.hidden = i !== this.index })
    this.selectorTargets.forEach((button, i) => button.setAttribute("aria-pressed", String(i === this.index)))
    if (this.hasStatusTarget) this.statusTarget.textContent = this.panelTargets[this.index].dataset.label || ""
  }

  disconnect() {
    this.requested = this.index
    this.clearAnimations()
  }
}
