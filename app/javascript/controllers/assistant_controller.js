import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["orb", "panel"]

  connect() {
    this.x = 24
    this.y = innerHeight - 88
    try {
      const saved = JSON.parse(localStorage.getItem("shuffl-assistant-position"))
      if (saved && Number.isFinite(saved.x) && Number.isFinite(saved.y)) {
        this.x = saved.x; this.y = saved.y
      }
    } catch (_) {}
    this.resize()
  }

  resize() {
    this.x = Math.max(12, Math.min(this.x, innerWidth - 72))
    this.y = Math.max(12, Math.min(this.y, innerHeight - 72))
    this.orbTarget.style.left = `${this.x}px`
    this.orbTarget.style.top = `${this.y}px`
    if (!this.panelTarget.hidden) {
      const width = this.panelTarget.offsetWidth
      const height = this.panelTarget.offsetHeight
      const left = this.x + 72 + width <= innerWidth - 12 ? this.x + 72 : this.x - width - 12
      this.panelTarget.style.left = `${Math.max(12, Math.min(left, innerWidth - width - 12))}px`
      this.panelTarget.style.top = `${Math.max(12, Math.min(this.y, innerHeight - height - 12))}px`
    }
  }

  start(event) {
    if (event.button !== 0 || !event.isPrimary) return
    this.drag = { id: event.pointerId, x: event.clientX, y: event.clientY, left: this.x, top: this.y }
    this.moved = false
    this.orbTarget.setPointerCapture(event.pointerId)
  }

  move(event) {
    if (!this.drag || event.pointerId !== this.drag.id) return
    const dx = event.clientX - this.drag.x, dy = event.clientY - this.drag.y
    if (Math.hypot(dx, dy) > 5) this.moved = true
    if (!this.moved) return
    this.x = this.drag.left + dx; this.y = this.drag.top + dy
    this.orbTarget.classList.add("is-dragging")
    this.resize()
  }

  end(event) {
    if (!this.drag || event.pointerId !== this.drag.id) return
    this.orbTarget.releasePointerCapture(event.pointerId)
    this.drag = null
    this.orbTarget.classList.remove("is-dragging")
    this.save()
  }

  cancel() {
    this.drag = null
    this.moved = false
    this.orbTarget.classList.remove("is-dragging")
  }

  toggle(event) {
    if (this.moved && event.detail !== 0) { this.moved = false; return }
    this.panelTarget.hidden = !this.panelTarget.hidden
    this.orbTarget.setAttribute("aria-expanded", String(!this.panelTarget.hidden))
    this.resize()
  }

  close() {
    const focusInside = this.panelTarget.contains(document.activeElement)
    this.panelTarget.hidden = true
    this.orbTarget.setAttribute("aria-expanded", "false")
    if (focusInside) this.orbTarget.focus()
  }

  keyboard(event) {
    const directions = { ArrowLeft: [-20, 0], ArrowRight: [20, 0], ArrowUp: [0, -20], ArrowDown: [0, 20] }
    const delta = directions[event.key]
    if (!delta) return
    event.preventDefault()
    this.x += delta[0]; this.y += delta[1]
    this.resize(); this.save()
  }

  save() {
    try { localStorage.setItem("shuffl-assistant-position", JSON.stringify({ x: this.x, y: this.y })) } catch (_) {}
  }
}
