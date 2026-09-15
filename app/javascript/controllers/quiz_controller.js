import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "answer", "heading", "status", "done", "option", "ordered", "board", "slots", "pool"]
  static values = { limit: Number, ranked: Boolean }

  // Separator chosen because it cannot appear in an option label.
  static SEPARATOR = "\u001F"

  connect() {
    this.busy = false
    // Click order is the answer for a ranked question, so it is tracked here
    // rather than read back off the DOM, which only knows document order.
    this.order = this.rankedValue && this.hasOrderedTarget
      ? this.orderedTarget.value.split(this.constructor.SEPARATOR).filter(Boolean)
      : []
    if (this.rankedValue && this.hasBoardTarget) this.setupRanking()
    this.update()
    this.headingTarget.focus({ preventScroll: true })
  }

  disconnect() { this.cancel(); this.rankingEvents?.abort(); this.endDrag() }
  cancel() { clearTimeout(this.timer) }

  reselect(event) {
    // A saved radio answer can be selected again after going Back.
    if (event.target.checked) this.choose()
  }

  choose(event) {
    if (this.busy) return
    this.cancel()
    if (this.rankedValue && event) this.track(event.target)
    const count = this.update()
    // A ranked question is finished by the Done button, not by hitting the cap:
    // two ranked choices is a legitimate answer and should not auto-advance.
    if (!this.rankedValue && count === this.limitValue) {
      this.statusTarget.textContent = "Answer selected. Moving on…"
      // Briefly show the selected state before navigating; never submit on focus.
      this.timer = setTimeout(() => this.formTarget.requestSubmit(), 250)
    }
  }

  // Records the order boxes were ticked, and drops one when it is unticked so
  // the remaining ranks close up rather than leaving a gap.
  track(input) {
    const value = input.value
    const at = this.order.indexOf(value)
    if (input.checked && at === -1) this.order.push(value)
    if (!input.checked && at !== -1) this.order.splice(at, 1)
    if (this.hasOrderedTarget) this.orderedTarget.value = this.order.join(this.constructor.SEPARATOR)
  }

  update() {
    const count = this.answerTargets.filter(answer => answer.checked).length
    if (this.limitValue > 1) {
      this.answerTargets.forEach(answer => { answer.disabled = count >= this.limitValue && !answer.checked })
      this.statusTarget.textContent = this.rankedValue
        ? this.rankSummary(count)
        : `${count} of ${this.limitValue} selected`
    }
    if (this.rankedValue) { this.paintRanks(); if (this.hasBoardTarget) this.renderRanking() }
    if (this.hasDoneTarget) this.doneTarget.disabled = count === 0
    return count
  }

  rankSummary(count) {
    if (count === 0) return `Pick up to ${this.limitValue}, most important first.`
    const names = this.order.map((value, index) => `${index + 1}. ${value}`).join(", ")
    return `${names}. Pick up to ${this.limitValue}.`
  }

  paintRanks() {
    this.answerTargets.forEach(answer => {
      const label = this.optionTargets.find(option => option.control === answer || option.contains(answer))
      if (!label) return
      const position = this.order.indexOf(answer.value)
      const badge = label.querySelector(".quiz-rank")
      if (badge) badge.textContent = position === -1 ? "" : String(position + 1)
      label.classList.toggle("is-ranked", position !== -1)
    })
  }

  setupRanking() {
    this.element.classList.add("ranking-ready")
    this.boardTarget.hidden = false
    this.rankingEvents = new AbortController()
    const listen = (type, handler) => this.boardTarget.addEventListener(type, handler, { signal: this.rankingEvents.signal })
    listen("click", event => {
      if (this.suppressClick) { this.suppressClick = false; return }
      const button = event.target.closest("button[data-value]")
      if (!button || this.busy) return
      const value = button.dataset.value
      const index = this.order.indexOf(value)
      if (button.dataset.operation === "remove") this.place(value, -1)
      else if (button.dataset.operation === "up") this.place(value, index - 1)
      else if (button.dataset.operation === "down") this.place(value, index + 1)
      else if (index < 0) this.place(value, this.order.length)
    })
    listen("pointerdown", event => {
      const item = event.target.closest("[data-draggable]")
      if (!item || event.button !== 0 || this.busy) return
      this.suppressClick = false
      this.drag = { value: item.dataset.value, x: event.clientX, y: event.clientY, id: event.pointerId }
      this.boardTarget.setPointerCapture(event.pointerId)
    })
    listen("pointermove", event => {
      if (!this.drag) return
      if (!this.ghost && Math.hypot(event.clientX - this.drag.x, event.clientY - this.drag.y) < 6) return
      if (!this.ghost) {
        this.ghost = document.createElement("div")
        this.ghost.className = "rank-drag-ghost"
        this.ghost.textContent = this.drag.value
        this.ghost.setAttribute("aria-hidden", "true")
        this.element.append(this.ghost)
      }
      this.ghost.style.transform = `translate(${event.clientX + 12}px, ${event.clientY - 24}px)`
      this.boardTarget.querySelectorAll(".is-drop-target").forEach(el => el.classList.remove("is-drop-target"))
      document.elementFromPoint(event.clientX, event.clientY)?.closest("[data-slot], .rank-cloud")?.classList.add("is-drop-target")
    })
    listen("pointerup", event => {
      if (!this.drag) return
      const value = this.drag.value
      const moved = !!this.ghost
      const target = document.elementFromPoint(event.clientX, event.clientY)
      const slot = target?.closest("[data-slot]")
      const pool = target?.closest(".rank-cloud")
      this.endDrag()
      if (moved) {
        this.suppressClick = true
        if (slot) this.place(value, Number(slot.dataset.slot))
        else if (pool) this.place(value, -1)
      } else if (!this.order.includes(value)) {
        this.suppressClick = true
        this.place(value, this.order.length)
      }
    })
    listen("pointercancel", () => this.endDrag())
    listen("keydown", event => {
      if (event.key === "Escape") { this.endDrag(); return }
      const item = event.target.closest("[data-draggable]")
      if (!item || !["ArrowUp", "ArrowDown"].includes(event.key)) return
      const index = this.order.indexOf(item.dataset.value)
      if (index < 0) return
      event.preventDefault()
      const target = index + (event.key === "ArrowUp" ? -1 : 1)
      if (target >= 0 && target < this.order.length) this.place(item.dataset.value, target)
    })
  }

  endDrag() {
    if (this.drag && this.hasBoardTarget && this.boardTarget.hasPointerCapture(this.drag.id)) this.boardTarget.releasePointerCapture(this.drag.id)
    this.drag = null
    this.ghost?.remove()
    this.ghost = null
    if (this.hasBoardTarget) this.boardTarget.querySelectorAll(".is-drop-target").forEach(el => el.classList.remove("is-drop-target"))
  }

  place(value, position) {
    if (this.busy) return
    const old = this.order.indexOf(value)
    if (position >= 0 && old < 0 && this.order.length >= this.limitValue) {
      this.statusTarget.textContent = "Your three slots are full. Remove a choice before adding another."
      return
    }
    if (old >= 0) this.order.splice(old, 1)
    if (position >= 0) this.order.splice(Math.min(position, this.order.length), 0, value)
    this.orderedTarget.value = this.order.join(this.constructor.SEPARATOR)
    this.answerTargets.forEach(input => { input.checked = this.order.includes(input.value) })
    this.update()
    // Keep keyboard focus on the moved item (or its returned pool choice).
    ;[...this.boardTarget.querySelectorAll("[data-draggable]")].find(el => el.dataset.value === value)?.focus({ preventScroll: true })
  }

  rankButton(value, label, operation = "item") {
    const button = document.createElement("button")
    button.type = "button"
    button.dataset.value = value
    button.dataset.operation = operation
    button.textContent = label
    if (operation === "item") button.dataset.draggable = "true"
    return button
  }

  renderRanking() {
    this.slotsTarget.replaceChildren()
    for (let index = 0; index < this.limitValue; index++) {
      const row = document.createElement("div")
      row.className = "rank-slot"
      row.dataset.slot = index
      const number = document.createElement("span")
      number.className = "rank-position"
      number.textContent = String(index + 1).padStart(2, "0")
      row.append(number)
      const value = this.order[index]
      if (value) {
        row.classList.add("is-filled")
        const item = this.rankButton(value, value)
        item.className = "rank-item"
        item.setAttribute("aria-label", `${value}, rank ${index + 1}. Use up and down arrows to reorder.`)
        row.append(item)
        const controls = document.createElement("div")
        controls.className = "rank-item-controls"
        for (const [op, label] of [["up", "↑"], ["down", "↓"], ["remove", "×"]]) {
          const button = this.rankButton(value, label, op)
          button.setAttribute("aria-label", `${op === "remove" ? "Remove" : "Move " + op} ${value}`)
          button.disabled = (op === "up" && index === 0) || (op === "down" && index === this.order.length - 1)
          controls.append(button)
        }
        row.append(controls)
      } else {
        const placeholder = document.createElement("span")
        placeholder.className = "rank-placeholder"
        placeholder.textContent = index === 0 ? "Your first priority" : "Drop a choice here"
        row.append(placeholder)
      }
      this.slotsTarget.append(row)
    }
    this.poolTarget.replaceChildren()
    this.answerTargets.filter(input => !this.order.includes(input.value)).forEach(input => {
      const button = this.rankButton(input.value, input.value)
      button.className = "rank-choice"
      button.setAttribute("aria-label", `Add ${input.value} to your ranking`)
      this.poolTarget.append(button)
    })
  }

  submitting(event) {
    if (this.busy) { event.preventDefault(); return }
    this.cancel()
    this.busy = true
    this.formTarget.setAttribute("aria-busy", "true")
  }

  finished(event) {
    if (!event.detail.success) {
      this.busy = false
      this.formTarget.removeAttribute("aria-busy")
      this.statusTarget.textContent = "Your answer wasn't saved. Please select it again."
    }
  }
}
