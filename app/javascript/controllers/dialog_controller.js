import { Controller } from "@hotwired/stimulus"

// Opens and closes a native <dialog>. Escape already closes it; this adds
// a close button and clicking the backdrop.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
