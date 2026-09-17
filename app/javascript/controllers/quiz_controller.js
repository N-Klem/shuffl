import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "answer", "heading", "status", "done", "option", "ordered", "budgetField", "budgetInput", "ranking", "selected", "choices"]
  static values = { limit: Number, ranked: Boolean, budget: Boolean }

  // Separator chosen because it cannot appear in an option label.
  static SEPARATOR = ""

  connect() {
    this.busy = false
    // Keep the selected order separate from the original option order.
    this.order = this.rankedValue && this.hasOrderedTarget
      ? this.orderedTarget.value.split(this.constructor.SEPARATOR).filter(Boolean)
      : []
    this.update()
    this.headingTarget.focus({ preventScroll: true })
  }

  disconnect() { this.cancel() }
  cancel() { clearTimeout(this.timer) }

  reselect(event) {
    // A saved radio answer can be selected again after going Back.
    if (event.target.checked) this.choose()
  }

  choose(event) {
    if (this.busy) return
    this.cancel()
    if (event?.target.checked && event.target.type === "checkbox" && !this.rankedValue) {
      this.answerTargets.forEach(input => {
        if (input !== event.target && (event.target.dataset.exclusive === "true" || input.dataset.exclusive === "true")) input.checked = false
      })
    }
    const pill = this.rankedValue && event ? event.target.closest(".quiz-answer") : null
    const before = pill?.getBoundingClientRect()
    if (this.rankedValue && event) this.track(event.target)
    const count = this.update()
    if (pill && before && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      const after = pill.getBoundingClientRect()
      pill.animate([
        { transform: `translate(${before.left - after.left}px, ${before.top - after.top}px)` },
        { transform: "translate(0, 0)" }
      ], { duration: 200, easing: "ease-out" })
    }
    // A ranked question is finished by the Continue button, not by hitting the cap:
    // two ranked choices is a legitimate answer and should not auto-advance.
    if (!this.rankedValue && this.limitValue === 1 && count === 1 &&
        (!this.budgetValue || !this.answerTargets.some(input => input.checked && input.value === "Custom"))) {
      this.statusTarget.textContent = "Answer selected. Moving on…"
      // Briefly show the selected state before navigating; never submit on focus.
      this.timer = setTimeout(() => this.formTarget.requestSubmit(), 250)
    }
  }

  // Records the order pills were tapped, and drops one when it is tapped again
  // so the remaining ranks close up rather than leaving a gap.
  track(input) {
    const value = input.value
    const at = this.order.indexOf(value)
    if (input.checked && at === -1) this.order.push(value)
    if (!input.checked && at !== -1) this.order.splice(at, 1)
    if (this.hasOrderedTarget) this.orderedTarget.value = this.order.join(this.constructor.SEPARATOR)
  }

  update() {
    this.statusTarget.classList.remove("is-error")
    const count = this.answerTargets.filter(answer => answer.checked).length
    if (this.limitValue > 1) {
      this.answerTargets.forEach(answer => { answer.disabled = count >= this.limitValue && !answer.checked })
      this.statusTarget.textContent = this.rankedValue
        ? this.rankSummary(count)
        : `${count} of ${this.limitValue} selected`
    }
    if (this.rankedValue) this.paintRanks()
    if (this.hasDoneTarget) this.doneTarget.disabled = count === 0
    if (this.budgetValue) {
      const custom = this.answerTargets.some(input => input.checked && input.value === "Custom")
      this.doneTarget.hidden = !custom
      this.budgetFieldTarget.hidden = !custom
      this.budgetInputTarget.disabled = !custom
      this.budgetInputTarget.required = custom
      this.doneTarget.disabled = count === 0 || (custom && !this.budgetInputTarget.checkValidity())
    }
    return count
  }

  // Before the first tap the question's own explanation carries the instruction,
  // so the status stays empty rather than saying it twice.
  rankSummary(count) {
    return count ? `${count} of ${this.limitValue} selected. Continue when you're ready.` : ""
  }

  paintRanks() {
    this.rankingTarget.hidden = false
    this.optionTargets.forEach(label => {
      const input = label.querySelector("input")
      const selected = this.order.includes(input.value)
      label.classList.toggle("is-ranked", selected)
      label.querySelector(".quiz-drag-handle").hidden = !selected
      if (!selected) this.choicesTarget.append(label)
    })
    this.order.forEach(value => {
      const label = this.optionTargets.find(option => option.querySelector("input").value === value)
      if (label) this.selectedTarget.append(label)
    })
    this.orderedTarget.value = this.order.join(this.constructor.SEPARATOR)
  }

  handleClick(event) {
    event.preventDefault()
    event.stopPropagation()
  }

  dragStart(event) {
    if (event.button !== 0 || this.busy) return
    event.preventDefault()
    this.dragged = event.currentTarget.closest(".quiz-answer")
    this.dragged.classList.add("is-dragging")
    event.currentTarget.setPointerCapture(event.pointerId)
  }

  dragMove(event) {
    if (!this.dragged) return
    event.preventDefault()
    const target = document.elementFromPoint(event.clientX, event.clientY)?.closest(".quiz-answer")
    if (!target || target === this.dragged || !this.selectedTarget.contains(target)) return
    const value = this.dragged.querySelector("input").value
    const destination = this.order.indexOf(target.querySelector("input").value)
    this.order.splice(this.order.indexOf(value), 1)
    this.order.splice(destination, 0, value)
    // Move the other pills around the captured handle to keep touch capture intact.
    const labels = this.order.map(item => this.optionTargets.find(label => label.querySelector("input").value === item))
    const pivot = labels.indexOf(this.dragged)
    labels.slice(0, pivot).forEach(label => this.selectedTarget.insertBefore(label, this.dragged))
    labels.slice(pivot + 1).forEach(label => this.selectedTarget.append(label))
    this.orderedTarget.value = this.order.join(this.constructor.SEPARATOR)
  }

  dragEnd() {
    if (!this.dragged) return
    this.dragged.classList.remove("is-dragging")
    this.dragged = null
    this.statusTarget.textContent = "Priority order updated."
  }

  reorderKey(event) {
    const direction = { ArrowUp: -1, ArrowLeft: -1, ArrowDown: 1, ArrowRight: 1 }[event.key]
    if (!direction) return
    event.preventDefault()
    const value = event.currentTarget.closest(".quiz-answer").querySelector("input").value
    const index = this.order.indexOf(value)
    const next = index + direction
    if (next < 0 || next >= this.order.length) return
    this.order.splice(index, 1)
    this.order.splice(next, 0, value)
    this.paintRanks()
    event.currentTarget.focus()
    this.statusTarget.textContent = `${value} moved to priority ${next + 1}.`
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
      this.statusTarget.classList.add("is-error")
      this.statusTarget.textContent = "Your answer wasn't saved. Please select it again."
    }
  }
}
