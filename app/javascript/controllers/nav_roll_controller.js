import { Controller } from "@hotwired/stimulus"

// Staggered text-roll hover effect for navigation links.
// Attach to the <nav> (or any wrapper whose links get the effect).
// Each link's visible text is replaced by two copies — on hover the
// first slides up while the second slides in from below, one letter at
// a time radiating from the centre.

const STAGGER = 0.035 // seconds between adjacent letters

export default class extends Controller {
  connect () {
    this.element.querySelectorAll(".nav-links a, .mobile-navigation-menu a").forEach(link => {
      this.#roll(link)
    })
  }

  // ---------- private ----------

  #roll (link) {
    const word = link.textContent.trim().toLowerCase()
    // Guard: skip if already rolled (Turbo re-connect) or empty
    if (link.querySelector(".nav-roll") || !word) return

    // Preserve the active class and other attributes
    const wrap = document.createElement("span")
    wrap.className = "nav-roll"
    wrap.setAttribute("aria-hidden", "true")

    for (let row = 0; row < 2; row++) {
      const line = document.createElement("span")
      line.className = "nav-roll-line"
      ;[...word].forEach((char, i) => {
        const span = document.createElement("span")
        span.className = "nav-roll-letter"
        span.textContent = char === " " ? " " : char
        // Delay radiates from centre
        const delay = STAGGER * Math.abs(i - (word.length - 1) / 2)
        span.style.setProperty("--delay", `${delay}s`)
        line.appendChild(span)
      })
      wrap.appendChild(line)
    }

    // Keep accessible label but swap visible content
    link.setAttribute("aria-label", word)
    link.textContent = ""
    link.appendChild(wrap)
  }
}
