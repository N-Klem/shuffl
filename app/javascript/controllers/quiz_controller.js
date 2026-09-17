import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "answer", "heading", "status", "done", "option", "ordered", "budgetField", "budgetInput"]
  static values = { limit: Number, ranked: Boolean, budget: Boolean }

  // Separator chosen because it cannot appear in an option label.
  static SEPARATOR = ""

  connect() {
    this.busy = false
    // Tap order is the answer for a ranked question, so it is tracked here
    // rather than read back off the DOM, which only knows document order.
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
    if (this.rankedValue && event) this.track(event.target)
    const count = this.update()
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

  rankSummary(count) {
    if (count === 0) return `Tap up to ${this.limitValue}, most important first.`
    const names = this.order.map((value, index) => `${index + 1} ${value}`).join(" · ")
    const next = count < this.limitValue ? "Tap one more, or continue." : "Tap a choice again to remove it."
    return `${names} · ${next}`
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
