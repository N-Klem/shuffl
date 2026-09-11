import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "answer", "heading", "status", "done"]
  static values = { limit: Number }

  connect() {
    this.busy = false
    this.update()
    this.headingTarget.focus({ preventScroll: true })
  }

  disconnect() { this.cancel() }
  cancel() { clearTimeout(this.timer) }

  reselect(event) {
    // A saved radio answer can be selected again after going Back.
    if (event.target.checked) this.choose()
  }

  choose() {
    if (this.busy) return
    this.cancel()
    const count = this.update()
    if (count === this.limitValue) {
      this.statusTarget.textContent = "Answer selected. Moving on…"
      // Briefly show the selected state before navigating; never submit on focus.
      this.timer = setTimeout(() => this.formTarget.requestSubmit(), 250)
    }
  }

  update() {
    const count = this.answerTargets.filter(answer => answer.checked).length
    if (this.limitValue > 1) {
      this.answerTargets.forEach(answer => { answer.disabled = count >= this.limitValue && !answer.checked })
      this.statusTarget.textContent = `${count} of ${this.limitValue} selected`
    }
    if (this.hasDoneTarget) this.doneTarget.disabled = count === 0
    return count
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
