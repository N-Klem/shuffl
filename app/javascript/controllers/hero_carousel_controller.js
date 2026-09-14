import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "caption"]

  connect() {
    this.phase = 0
    this.lastFrame = null
    this.selection = null
    this.motion = matchMedia("(prefers-reduced-motion: reduce)")
    this.changed = () => { this.pause(); this.resume() }
    this.visibility = () => document.hidden ? this.pause() : this.resume()
    this.motion.addEventListener("change", this.changed)
    document.addEventListener("visibilitychange", this.visibility)
    this.resize = new ResizeObserver(() => {
      const width = this.element.clientWidth
      const cardWidth = this.cardTargets[0]?.offsetWidth || 220
      this.radius = Math.max(35, (width - cardWidth) / 2 - 12)
      this.draw()
    })
    this.resize.observe(this.element)
    this.draw()
    this.resume()
  }

  draw() {
    const count = this.cardTargets.length
    if (!count) return
    this.cardTargets.forEach((card, i) => {
      const angle = (i - this.phase) * 2 * Math.PI / count
      const depth = (Math.cos(angle) + 1) / 2
      const x = Math.sin(angle) * (this.radius || 100)
      const y = (1 - depth) * -32
      const scale = .68 + depth * .32
      // Upright cards travel around a horizontal ellipse, with the rear cards smaller.
      card.style.transform = `translate(${x}px, ${y}px) scale(${scale})`
      card.style.opacity = String(.28 + depth * .72)
      card.style.zIndex = String(Math.round(depth * 100))
    })
    const front = ((Math.round(this.phase) % count) + count) % count
    if (front !== this.front) {
      this.front = front
      this.captionTarget.textContent = this.cardTargets[front].dataset.caption || ""
      this.cardTargets.forEach((card, i) => card.setAttribute("aria-pressed", String(i === front)))
    }
  }

  tick(time) {
    const dt = this.lastFrame === null ? 0 : Math.min((time - this.lastFrame) / 1000, .05)
    this.lastFrame = time
    if (this.selection !== null) {
      this.phase += (this.selection - this.phase) * (1 - Math.exp(-dt / .3))
      if (Math.abs(this.selection - this.phase) < .005) this.selection = null
    } else {
      this.phase += dt / 4.8
    }
    this.draw()
    this.frame = requestAnimationFrame(now => this.tick(now))
  }

  select(event) {
    const count = this.cardTargets.length
    const index = Number(event.currentTarget.dataset.index)
    const current = ((this.phase % count) + count) % count
    let distance = index - current
    if (distance > count / 2) distance -= count
    if (distance < -count / 2) distance += count
    if (this.motion.matches) {
      this.phase += distance
      this.selection = null
      this.draw()
    } else this.selection = this.phase + distance
  }

  pause() { cancelAnimationFrame(this.frame); this.lastFrame = null }
  resume() {
    this.pause()
    if (this.motion.matches || document.hidden || this.cardTargets.length < 2) return
    this.frame = requestAnimationFrame(now => this.tick(now))
  }
  disconnect() {
    this.pause()
    this.resize.disconnect()
    this.motion.removeEventListener("change", this.changed)
    document.removeEventListener("visibilitychange", this.visibility)
  }
}
