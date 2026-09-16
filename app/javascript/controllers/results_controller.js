import { gatherCards } from "controllers/motion_helpers"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { payload: Object, quizId: Number, saveUrl: String }

  connect() {
    const root = this.element
    const escape = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]))
    const catalog = this.payloadValue.cards
    const selected = [...this.payloadValue.selected]
    const kept = selected.map(() => false)
    const storageKey = 'shuffl-results-cards-v1-' + this.quizIdValue
    let savedSnapshot = null
    const snapshot = () => JSON.stringify({ selected: selected.map(i => catalog[i].id), kept })
    const persist = () => { try { sessionStorage.setItem(storageKey, snapshot()) } catch {} }
    const syncSave = () => {
      const same = savedSnapshot === snapshot()
      root.querySelector('#save-stack').textContent = same ? 'Stack saved' : 'Save this stack'
      root.querySelector('#save-status').textContent = same ? 'Saved to My Wallet.' : 'Save these cards to My Wallet.'
    }
    // Preserve earlier Keep/Swap choices without importing any spending assumptions.
    try {
      const stored = JSON.parse(sessionStorage.getItem(storageKey) || sessionStorage.getItem('shuffl-results-cashback-v1-' + this.quizIdValue))
      if (stored?.selected?.length === selected.length && new Set(stored.selected).size === selected.length &&
          stored.selected.every(id => catalog.some(c => c.id === id)) && stored.kept?.length === selected.length &&
          stored.kept.every(value => typeof value === 'boolean')) {
        selected.splice(0, selected.length, ...stored.selected.map(id => catalog.findIndex(c => c.id === id)))
        kept.splice(0, kept.length, ...stored.kept)
      }
    } catch {}

    const rate = rule => escape(rule.rate) + ({ cashback_percent: '% cashback', points_per_USD: Number(rule.rate) === 1 ? ' point per $1' : ' points per $1', miles_per_USD: Number(rule.rate) === 1 ? ' mile per $1' : ' miles per $1' }[rule.unit] || '')
    const money = value => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 0, maximumFractionDigits: 2 }).format(value)
    const hooks = {
      'Online shopping': 'Your online shopper', 'Groceries': 'Your grocery go-to',
      'Dining out': 'Your dining companion', 'Entertainment & subscriptions': 'Your downtime card',
      'Gas & transport': 'Your commute companion', 'Travel': 'Your travel companion',
      'Rent or bills': 'Your bill-paying card', 'everyday': 'Your everyday earner'
    }
    const render = () => {
      const assignedUses = new Set()
      root.querySelector('#cards').innerHTML = selected.map((id, i) => {
        const c = catalog[id], options = c.recommendedUses || []
        const use = options.find(option => !assignedUses.has(option.use_key)) || options[0]
        if (use) assignedUses.add(use.use_key)
        const hook = c.valueProfile.kind === 'credit' ? 'Your credit builder' : use ? (hooks[use.use_key] || 'Your rewards companion') : 'Your card benefits'
        return `<article class="recommendation" aria-label="${escape(c.name)}">
          <div class="art-column"><a class="card-link" href="${escape(c.url)}" aria-label="Explore ${escape(c.name)} in detail" style="--metal:${c.finish};--card-ink:${c.ink}">
            <div class="face ${c.imageUrl ? 'has-card-image' : ''}" aria-hidden="true">${c.imageUrl ? `<img class="card-image" src="${escape(c.imageUrl)}" alt="" decoding="async">` : `<span class="card-name">${escape(c.name)}</span>`}</div>
          </a></div>
          <div class="recommendation-copy"><div class="card-identity"><p class="card-hook">${escape(hook)}</p><h2>${escape(c.name)}</h2></div>
            ${use ? `<div class="recommended-use"><p class="use-reward">${rate(use)}</p><h3>Use for ${escape(use.use_for)}</h3>${use.conditions ? `<p class="caption">${escape(use.conditions)}</p>` : ''}</div>` : `<p class="card-benefit">${escape(c.valueProfile.detail)}</p>`}
            ${c.ongoingFee != null ? `<div class="card-fee ${c.ongoingFee > 0 ? 'has-fee' : 'no-fee'}"><strong>${c.ongoingFee > 0 ? '−' : ''}${escape(money(c.ongoingFee))}</strong><span>${c.ongoingFee === 0 ? 'No annual fee' : 'Ongoing card fees / year'}</span></div>` : ''}
            <div class="card-bottom"><details class="why"><summary>Why this card?</summary>${(c.matchReasons || []).map(reason => `<p>${escape(reason)}</p>`).join('')}${c.perks.slice(0, 2).map(perk => `<p>${escape(perk)}</p>`).join('')}<a href="${escape(c.url)}">Full card details and terms ↗</a></details>
            <div class="actions"><button class="keep" data-keep="${i}" aria-pressed="${kept[i]}" aria-label="${kept[i] ? 'Unkeep' : 'Keep'} ${escape(c.name)}">${kept[i] ? 'Kept' : 'Keep'}</button><button data-swap="${i}" aria-label="Swap ${escape(c.name)}" ${kept[i] || catalog.length === selected.length ? 'disabled' : ''}>Swap</button></div></div>
          </div></article>`
      }).join('')
      root.querySelector('#kept-count').textContent = `${selected.length} ${selected.length === 1 ? 'card' : 'cards'} · ${kept.filter(Boolean).length} kept`
      persist()
      syncSave()
    }
    const onCardsClick = event => {
      const button = event.target.closest('[data-keep], [data-swap]')
      if (!button) return
      const keeping = button.hasAttribute('data-keep')
      const i = Number(keeping ? button.dataset.keep : button.dataset.swap)
      if (keeping) kept[i] = !kept[i]
      else {
        const available = catalog.map((_, index) => index).filter(index => !selected.includes(index) && !catalog[index].retired)
        const next = available.find(index => index > selected[i]) ?? available[0]
        if (next === undefined) return
        selected[i] = next
      }
      render()
      root.querySelector(`[data-${keeping ? 'keep' : 'swap'}="${i}"]`).focus()
      root.querySelector('#status').textContent = keeping ? `${catalog[selected[i]].name} ${kept[i] ? 'kept.' : 'can now be swapped.'}` : `Swapped to ${catalog[selected[i]].name}.`
    }
    const onSave = async () => {
      const button = root.querySelector('#save-stack'), state = snapshot()
      persist()
      button.disabled = true
      button.textContent = 'Saving…'
      try {
        const response = await fetch(this.saveUrlValue, {
          method: 'POST', headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content },
          body: JSON.stringify({ quiz_response_id: this.quizIdValue, card_ids: selected.map(i => catalog[i].id) })
        })
        const result = await response.json()
        if (response.status === 401) {
          root.querySelector('#save-status').innerHTML = `<a href="${escape(result.sign_in_url)}">Sign in to save this stack</a>. Your choices will be here when you return.`
          button.textContent = 'Save this stack'
        } else if (response.ok) {
          await gatherCards(root.querySelectorAll('.card-link'), button)
          savedSnapshot = state
          syncSave()
          if (state === snapshot()) root.querySelector('#save-status').innerHTML = `Saved. <a href="${escape(result.wallet_url)}">View My Wallet</a>`
        } else throw new Error('Save failed')
      } catch {
        root.querySelector('#save-status').textContent = 'Could not save this stack. Please try again.'
        button.textContent = 'Save this stack'
      } finally { button.disabled = false }
    }
    root.querySelector('#cards').addEventListener('click', onCardsClick)
    root.querySelector('#save-stack').addEventListener('click', onSave)
    this.cleanup = () => {
      root.querySelector('#cards').removeEventListener('click', onCardsClick)
      root.querySelector('#save-stack').removeEventListener('click', onSave)
    }
    render()
  }

  disconnect() { this.cleanup?.() }
}
