import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "answer", "heading", "status", "done", "option", "ordered"]
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
    if (this.rankedValue) this.paintRanks()
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
