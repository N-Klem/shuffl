import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["orb", "panel", "messages", "feedback", "form", "input", "send", "clear", "starters", "status", "intro", "transcript", "avatar"]
  static values = { url: String, saveUrl: String, walletUrl: String, name: String }

  connect() {
    // Bottom-right by default, where DESIGN.md puts it and where left-aligned
    // headings and links are never underneath it. Until the user drags it the
    // position stays null and parkedX/parkedY follow the window; after a drag
    // it is theirs and only clamped at render time.
    this.x = null
    this.y = null
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

    // Any element on the page with data-assistant-ask opens the chat with that question.
    this.onAsk = event => {
      const trigger = event.target.closest("[data-assistant-ask]")
      if (!trigger) return
      event.preventDefault()
      this.ask(trigger.dataset.assistantAsk)
    }
    document.addEventListener("click", this.onAsk)

    // A panel left open stays open across page loads, like any chat widget.
    try { if (sessionStorage.getItem("shuffl-assistant-open") === "1") this.open(false) } catch (_) {}
  }

  disconnect() {
    this.request?.abort()
    if (this.pageObserver) this.pageObserver.disconnect()
    removeEventListener("load", this.repark)
    document.removeEventListener("click", this.onAsk)
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
      // Phone widths dock the panel as a sheet from the stylesheet; inline offsets would override it.
      if (innerWidth <= 640) { this.panelTarget.style.left = ""; this.panelTarget.style.top = ""; return }
      const width = this.panelTarget.offsetWidth
      const height = this.panelTarget.offsetHeight
      const anchor = this.parkedX()
      const left = anchor + 72 + width <= innerWidth - 12 ? anchor + 72 : anchor - width - 12
      this.panelTarget.style.left = `${Math.max(12, Math.min(left, innerWidth - width - 12))}px`
      this.panelTarget.style.top = `${Math.max(12, Math.min(top, innerHeight - height - 12))}px`
    }
  }

  parkedX() {
    return Math.max(12, Math.min(this.x ?? innerWidth - 84, innerWidth - 72))
  }

  // The orb is fixed to the viewport, so at the end of a page it would sit on
  // top of the footer with no way to scroll it clear. Let the footer push it up
  // rather than cover content.
  parkedY() {
    let y = Math.max(12, Math.min(this.y ?? innerHeight - 88, innerHeight - 72))
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
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open(focus = true) {
    this.panelTarget.hidden = false
    this.orbTarget.setAttribute("aria-expanded", "true")
    this.resize()
    try { sessionStorage.setItem("shuffl-assistant-open", "1") } catch (_) {}
    if (this.hasInputTarget) {
      if (focus) this.inputTarget.focus({ preventScroll: true })
      this.ensureLoaded()
    }
  }

  // One load per page, shared by whoever asks for it.
  ensureLoaded() {
    if (this.loaded) return Promise.resolve()
    this.loading ||= this.loadChat().finally(() => { this.loading = null })
    return this.loading
  }

  async ask(prompt) {
    this.open()
    if (!this.hasInputTarget) return
    await this.ensureLoaded()
    this.inputTarget.value = prompt
    this.formTarget.requestSubmit()
  }

  close() {
    const focusInside = this.panelTarget.contains(document.activeElement)
    this.panelTarget.hidden = true
    this.orbTarget.setAttribute("aria-expanded", "false")
    try { sessionStorage.removeItem("shuffl-assistant-open") } catch (_) {}
    if (focusInside) this.orbTarget.focus()
  }

  keyboard(event) {
    const directions = { ArrowLeft: [-20, 0], ArrowRight: [20, 0], ArrowUp: [0, -20], ArrowDown: [0, 20] }
    const delta = directions[event.key]
    if (!delta) return
    event.preventDefault()
    this.x = this.parkedX() + delta[0]; this.y = this.parkedY() + delta[1]
    this.resize(); this.save()
  }

  save() {
    try { localStorage.setItem("shuffl-assistant-position", JSON.stringify({ x: this.x, y: this.y })) } catch (_) {}
  }

  // Enter sends, as in every chat; Shift+Enter keeps the newline.
  keydown(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return
    event.preventDefault()
    this.formTarget.requestSubmit()
  }

  starter(event) {
    this.inputTarget.value = event.currentTarget.dataset.prompt
    this.formTarget.requestSubmit()
  }

  // The box grows with the question up to the stylesheet's max-height, then scrolls.
  grow() {
    this.inputTarget.style.height = ""
    this.inputTarget.style.height = `${this.inputTarget.scrollHeight}px`
  }

  async loadChat() {
    if (this.busy) return
    this.setBusy(true)
    try {
      const data = await this.fetchJson(this.urlValue)
      this.messagesTarget.replaceChildren()
      data.messages.forEach(message => {
        this.addQuestion(message.question)
        this.addReply(message.reply, message.question)
      })
      this.loaded = true
      this.showIntro(data.messages.length === 0)
      this.showRemaining(data.configured ? data.remaining : null)
      this.feedbackTarget.textContent = data.configured ? "" : "Chat isn't connected yet. You can still browse cards and stacks."
    } catch (error) { this.showError(error) }
    finally { this.setBusy(false); this.resize() }
  }

  async send(event) {
    event.preventDefault()
    if (this.busy || !this.formTarget.reportValidity()) return
    const question = this.inputTarget.value.trim()
    if (!question) return
    this.setBusy(true)
    this.showIntro(false)
    this.feedbackTarget.textContent = ""
    this.clearFollowups()
    this.addQuestion(question)
    this.inputTarget.value = ""
    this.inputTarget.style.height = ""
    this.addPending()
    try {
      const data = await this.fetchStream(this.urlValue, { message: question })
      this.removePending()
      this.addReply(data.reply, question)
      this.showRemaining(data.remaining)
    } catch (error) {
      this.removePending()
      this.addError(error.name === "AbortError" ? "That took too long. Please try again shortly." : error.message)
      this.inputTarget.value = question
    } finally {
      this.setBusy(false)
      this.resize()
      if (!this.panelTarget.hidden) this.inputTarget.focus({ preventScroll: true })
    }
  }

  async clearChat() {
    if (this.busy || !window.confirm("Clear this conversation? Your saved wallet cards will stay.")) return
    this.setBusy(true)
    try {
      await this.fetchJson(this.urlValue, "DELETE")
      this.messagesTarget.replaceChildren()
      this.showIntro(true)
      this.feedbackTarget.textContent = "Conversation cleared. Your daily message limit stays the same."
    } catch (error) { this.showError(error) }
    finally { this.setBusy(false); this.resize() }
  }

  async saveItem(event) {
    const button = event.currentTarget
    if (button.disabled) return
    const payload = button.dataset.stackId ? { stack_id: button.dataset.stackId } : { card_ids: [button.dataset.cardId] }
    button.disabled = true
    try {
      const data = await this.fetchJson(this.saveUrlValue, "POST", payload)
      button.textContent = "Saved to wallet"
      const link = this.node("a", "Open My Wallet →")
      link.href = this.walletUrlValue
      this.feedbackTarget.replaceChildren("Saved to Planned in My Wallet. ", link)
      this.dispatch("wallet-updated", { detail: { wallet: data.wallet } })
    } catch (error) { button.disabled = false; this.showError(error) }
  }

  async fetchJson(url, method = "GET", body) {
    const request = new AbortController()
    if (url === this.urlValue) this.request = request
    const timer = setTimeout(() => request.abort(), 28000)
    try {
      const response = await fetch(url, {
        method, credentials: "same-origin", signal: request.signal,
        headers: { "Accept": "application/json", "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
        ...(body ? { body: JSON.stringify(body) } : {})
      })
      if (response.status === 204) return {}
      const data = await response.json()
      if (!response.ok) throw new Error(data.error || "That action couldn't be completed. Please sign in and try again.")
      return data
    } finally { clearTimeout(timer) }
  }

  // A question's reply arrives as newline-delimited JSON: a progress line as each
  // stage of the work starts, then one final line with the reply or an error.
  // Failures before the first line come back as ordinary JSON with a status.
  async fetchStream(url, body) {
    const request = new AbortController()
    this.request = request
    const timer = setTimeout(() => request.abort(), 40000)
    try {
      const response = await fetch(url, {
        method: "POST", credentials: "same-origin", signal: request.signal,
        headers: { "Accept": "application/x-ndjson, application/json", "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
        body: JSON.stringify(body)
      })
      if (!response.headers.get("Content-Type")?.includes("x-ndjson")) {
        const data = await response.json()
        if (!response.ok) throw new Error(data.error || "That action couldn't be completed. Please sign in and try again.")
        return data
      }
      const reader = response.body.getReader(), decoder = new TextDecoder()
      let buffered = "", last = null
      for (;;) {
        const { value, done } = await reader.read()
        buffered += decoder.decode(value, { stream: !done })
        const lines = buffered.split("\n")
        buffered = done ? "" : lines.pop()
        for (const line of lines) {
          if (!line.trim()) continue
          const event = JSON.parse(line)
          if (event.progress !== undefined) this.addProgress(event.progress)
          else last = event
        }
        if (done) break
      }
      if (!last) throw new Error("I couldn't verify an answer right now. Please try again shortly.")
      if (last.error) throw new Error(last.error)
      return last
    } finally { clearTimeout(timer) }
  }

  setBusy(busy) {
    this.busy = busy
    this.sendTarget.disabled = busy
    this.clearTarget.disabled = busy
    this.messagesTarget.setAttribute("aria-busy", String(busy))
  }

  // The introduction and starters belong to an empty conversation only.
  showIntro(show) {
    this.introTarget.hidden = !show
    this.startersTarget.hidden = !show
  }

  // The daily allowance only matters when it is nearly used up.
  showRemaining(remaining) {
    this.statusTarget.textContent = Number.isFinite(remaining) && remaining <= 5 ? `${remaining} messages left today · ` : ""
  }

  showError(error) {
    this.feedbackTarget.textContent = error.name === "AbortError" ? "That took too long. Please try again shortly." : error.message
  }

  // Not named `element`: that is Stimulus's own property for the controller's root,
  // and shadowing it broke dispatch() after a wallet save.
  node(tag, text, className) {
    const element = document.createElement(tag)
    if (text !== undefined) element.textContent = text
    if (className) element.className = className
    return element
  }

  addQuestion(text) {
    const article = this.node("article", undefined, "assistant-message assistant-question")
    article.append(this.node("strong", "You", "assistant-who"), this.node("p", text))
    this.messagesTarget.append(article)
    this.scrollMessages()
  }

  // Every row from the assistant: avatar, a hidden name for screen readers, then the body.
  answerRow(className) {
    const article = this.node("article", undefined, ["assistant-message", "assistant-answer", className].filter(Boolean).join(" "))
    article.append(this.avatarTarget.content.firstElementChild.cloneNode(true))
    const body = this.node("div", undefined, "assistant-body")
    body.append(this.node("strong", this.nameValue, "assistant-who"))
    article.append(body)
    return [article, body]
  }

  // The wait sits in the transcript, where the answer will land. It fills with
  // the server's own progress ("Read 30 cards and 5 stacks · Checking issuer
  // sites · Writing") as each stage of the work starts.
  addPending() {
    const [article, body] = this.answerRow("assistant-pending")
    const dots = this.node("span", undefined, "assistant-typing")
    dots.append(this.node("i"), this.node("i"), this.node("i"))
    const text = this.node("p")
    text.append(this.node("span", undefined, "assistant-trail"), dots)
    body.append(text)
    this.messagesTarget.append(article)
    this.pending = article
    this.scrollMessages()
  }

  addProgress(label) {
    const trail = this.pending?.querySelector(".assistant-trail")
    if (!trail) return
    trail.append(this.node("span", label, "assistant-stage"))
    this.scrollMessages()
  }

  removePending() {
    this.pending?.remove()
    this.pending = null
  }

  addError(text) {
    const [article, body] = this.answerRow("assistant-error")
    body.append(this.node("p", text))
    this.messagesTarget.append(article)
    this.scrollMessages()
  }

  addReply(reply, question = "") {
    const [row, article] = this.answerRow()
    const sources = reply.sources || []
    ;(reply.paragraphs || []).forEach(paragraph => {
      // The site uses no em dashes; the model is told so, and this catches any that slip through.
      const p = this.node("p", String(paragraph.text ?? "").replace(/\s*—\s*/g, ", "))
      const cited = (paragraph.evidence_ids || []).map(id => sources.find(item => item.id === id)).filter(Boolean)
      // Three inline markers at most; a long run of citations reads as noise, so the
      // rest fold into the Sources list below.
      cited.slice(0, 3).forEach(source => {
        const link = this.node("a", ` [${sources.indexOf(source) + 1}]`)
        link.href = source.url
        link.target = "_blank"
        link.rel = "noopener noreferrer"
        link.setAttribute("aria-label", `Source: ${source.title}${source.checked_on ? `, checked ${source.checked_on}` : ""}`)
        p.append(link)
      })
      if (cited.length > 3) p.append(this.node("span", ` +${cited.length - 3} in sources`, "assistant-more-sources"))
      article.append(p)
    })
    ;(reply.cards || []).forEach(card => article.append(this.cardElement(card)))
    ;(reply.stacks || []).forEach(stack => {
      const detail = this.node("details", undefined, "assistant-item")
      detail.append(this.node("summary", stack.name), this.node("p", stack.description))
      if (stack.notes) detail.append(this.node("p", stack.notes))
      stack.cards.forEach(card => detail.append(this.cardElement(card)))
      this.addActions(detail, stack, "stack")
      article.append(detail)
    })
    if (sources.length) {
      const detail = this.node("details", undefined, "assistant-sources")
      detail.append(this.node("summary", "Sources"))
      sources.forEach((source, index) => {
        const p = this.node("p")
        const link = this.node("a", `${index + 1}. ${source.title}`)
        link.href = source.url; link.target = "_blank"; link.rel = "noopener noreferrer"
        p.append(link, document.createTextNode(source.type === "web" ? ` · issuer lookup, ${source.checked_on}` : " · catalogue snapshot"))
        detail.append(p)
      })
      article.append(detail)
    }
    // Only the latest reply offers follow-ups.
    this.clearFollowups()
    const followups = this.followups(reply, question)
    if (followups.length) {
      const group = this.node("div", undefined, "assistant-followups")
      group.setAttribute("role", "group")
      group.setAttribute("aria-label", "Follow-up questions")
      followups.forEach(({ label, prompt }) => {
        const button = this.node("button", label)
        button.type = "button"
        button.dataset.prompt = prompt
        button.dataset.action = "assistant#starter"
        group.append(button)
      })
      article.append(group)
    }
    this.messagesTarget.append(row)
    this.scrollMessages()
  }

  clearFollowups() {
    this.messagesTarget.querySelectorAll(".assistant-followups").forEach(group => group.remove())
  }

  // Up to two follow-ups, templated from the cards and stacks the reply named:
  // factual questions the catalogue can answer, never open-ended prompts. A
  // template is dropped when the question or the reply already covered it.
  followups(reply, question) {
    const cards = (reply.cards || []).map(card => card.name)
    const stacks = reply.stacks || []
    stacks.forEach(stack => (stack.cards || []).forEach(card => { if (!cards.includes(card.name)) cards.push(card.name) }))
    const asked = question.toLowerCase()
    const covered = `${asked} ${(reply.paragraphs || []).map(paragraph => paragraph.text).join(" ").toLowerCase()}`
    const [first, second] = cards
    const stack = stacks[0]?.name
    const options = [
      second && { label: `Compare ${first} and ${second}`, prompt: `Compare the ${first} and the ${second}.`, unless: /compar|versus|\bvs\b/.test(asked) },
      stack && { label: `Who the ${stack} stack is for`, prompt: `Who is the ${stack} stack for?`, unless: /\bwho\b|for me|suit/.test(asked) },
      first && { label: `${first} welcome offer`, prompt: `What's the welcome offer on the ${first}?`, unless: /welcome|bonus/.test(covered) },
      first && { label: `Foreign transaction fees on the ${first}`, prompt: `Does the ${first} charge foreign transaction fees?`, unless: /foreign/.test(covered) },
      first && { label: `Perks on the ${first}`, prompt: `What perks come with the ${first}?`, unless: /perk|benefit/.test(covered) },
      first && { label: `Who the ${first} is for`, prompt: `Who is the ${first} best for?`, unless: /\bwho\b|best for|suit/.test(asked) }
    ]
    return options.filter(option => option && !option.unless).slice(0, 2)
  }

  cardElement(card) {
    const detail = this.node("details", undefined, "assistant-item")
    detail.append(this.node("summary", card.name), this.node("p", `${card.issuer} · ${card.fee}`), this.node("p", card.rewards))
    if (card.description) detail.append(this.node("p", card.description))
    if (card.terms && Object.keys(card.terms).length) {
      const terms = this.node("details")
      terms.append(this.node("summary", "Details"), this.termsElement(card.terms))
      detail.append(terms)
    }
    this.addActions(detail, card, "card")
    return detail
  }

  // The terms a person asks about, in their words. The raw record also carries
  // research bookkeeping (review status, source labels) that has no place in a chat.
  termsElement(terms) {
    const list = this.node("dl", undefined, "assistant-terms")
    const add = (label, value) => {
      if (value === null || value === undefined || value === "" || (Array.isArray(value) && !value.length)) return
      list.append(this.node("dt", label))
      const dd = this.node("dd")
      if (Array.isArray(value)) {
        const ul = this.node("ul")
        value.forEach(item => ul.append(this.node("li", item)))
        dd.append(ul)
      } else {
        dd.textContent = value
      }
      list.append(dd)
    }
    const fees = terms.fees || {}
    const foreign = fees.foreign_purchase_percent
    const unitWord = { cashback_percent: "cashback", points_per_USD: "points", miles_per_USD: "miles" }
    add("Annual fee", fees.annual === null || fees.annual === undefined ? null : `$${fees.annual}`)
    add("Foreign transaction fee", foreign === null || foreign === undefined ? "Not recorded" : Number(foreign) === 0 ? "None" : `${foreign}%`)
    add("Rewards", (terms.rewards || []).map(rule =>
      `${rule.rate}${rule.unit === "cashback_percent" ? "%" : "x"} ${unitWord[rule.unit] || "rewards"} · ${rule.category}` +
      `${rule.conditions ? ` (${rule.conditions})` : ""}${rule.temporary ? " · limited time" : ""}`))
    add("Welcome offer", terms.welcome_offer)
    add("Perks", terms.perks)
    add("APR", terms.interest?.purchase_apr)
    add("First-year fee", fees.intro)
    add("Eligibility", terms.eligibility)
    return list
  }

  addActions(parent, item, type) {
    const actions = this.node("div", undefined, "assistant-item-actions")
    const link = this.node("a", "Full page ↗")
    link.href = item.url; link.target = "_blank"; link.rel = "noopener noreferrer"
    const button = this.node("button", item.saved ? "Saved to wallet" : `Save ${type} to wallet`)
    button.type = "button"; button.disabled = item.saved
    button.dataset[type === "stack" ? "stackId" : "cardId"] = item.id
    button.dataset.action = "assistant#saveItem"
    actions.append(link, button)
    parent.append(actions)
  }

  scrollMessages() {
    this.transcriptTarget.scrollTop = this.transcriptTarget.scrollHeight
    this.resize()
  }
}
