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

    // Layout is rarely final when a controller connects: browse and wallet render
    // client-side, and web fonts and card art land later. Until it settles the
    // footer sits near the top of a short document and the orb parks against it,
    // so re-park on the next frame, once everything has loaded, and whenever the
    // page changes size afterwards (filtering a list, opening a disclosure).
    this.repark = () => this.resize()
    requestAnimationFrame(this.repark)
    if (document.readyState !== "complete") {
      addEventListener("load", this.repark, { once: true })
    }
    if ("ResizeObserver" in window) {
      this.pageObserver = new ResizeObserver(this.repark)
      this.pageObserver.observe(document.body)
    }
  }

  disconnect() {
    if (this.pageObserver) this.pageObserver.disconnect()
    removeEventListener("load", this.repark)
  }

  // this.x/this.y are where the user put the orb. They are never overwritten by
  // layout: clamping happens at render time only. Clamping the stored value
  // instead meant one brief narrow viewport moved the orb permanently, because
  // the clamp can only ever shrink it and nothing restores it when space returns.
  resize() {
    this.orbTarget.style.left = `${this.parkedX()}px`
    const top = this.parkedY()
    this.orbTarget.style.top = `${top}px`
    if (!this.panelTarget.hidden) {
      const width = this.panelTarget.offsetWidth
      const height = this.panelTarget.offsetHeight
      const anchor = this.parkedX()
      const left = anchor + 72 + width <= innerWidth - 12 ? anchor + 72 : anchor - width - 12
      this.panelTarget.style.left = `${Math.max(12, Math.min(left, innerWidth - width - 12))}px`
      this.panelTarget.style.top = `${Math.max(12, Math.min(top, innerHeight - height - 12))}px`
    }
  }

  parkedX() {
    return Math.max(12, Math.min(this.x, innerWidth - 72))
  }

  // The orb is fixed to the viewport, so at the end of a page it would sit on
  // top of the footer with no way to scroll it clear. Let the footer push it up
  // rather than cover content.
  parkedY() {
    let y = Math.max(12, Math.min(this.y, innerHeight - 72))
    const footer = document.querySelector(".site-footer")
    if (footer) {
      const ceiling = footer.getBoundingClientRect().top - this.orbTarget.offsetHeight - 16
      y = Math.max(12, Math.min(y, ceiling))
    }
    return y
  }

  start(event) {
    if (event.button !== 0 || !event.isPrimary) return
    this.x = this.parkedX()
    this.y = this.parkedY()
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
