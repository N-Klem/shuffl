const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))
const number = n => new Intl.NumberFormat('en-US', { maximumFractionDigits: 2 }).format(n)
const money = n => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n)
export const earnings = row => row.unit === 'cashback' ? money(row.earned) + ' cashback' : number(row.earned) + ' ' + row.label + ' ' + row.unit
const rate = (n, unit) => number(n) + (unit === 'cashback' ? '% cashback' : ' ' + (n === 1 ? unit.replace(/s$/, '') : unit) + ' / $1')

export async function fetchPlan(cardIds, amounts, confirmed, programmes, signal) {
  const response = await fetch('/reward_estimates', {
    method: 'POST', signal,
    headers: { 'Content-Type': 'application/json', Accept: 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content },
    body: JSON.stringify({ card_ids: cardIds, amounts, confirmed, programmes, plan: true })
  })
  if (!response.ok) throw new Error('Could not refresh your spending plan.')
  return response.json()
}

export function programmeSelect(row, index, prefix = 'programme') {
  if (row.options.length < 2) return ''
  return `<label class="programme-choice" for="${prefix}-${index}">Rewards to earn<select id="${prefix}-${index}" name="programme${index}" data-programme="${index}"><option value="">Choose rewards</option>${row.options.map(option => `<option value="${escape(option.programme)}" ${row.programme === option.programme ? 'selected' : ''}>${escape(option.label)} · ${rate(option.rate, option.unit)}</option>`).join('')}</select></label>`
}

export function guideMarkup(plan, editable = true) {
  if (!plan?.categories.some(row => row.options.length)) return ''
  if (plan.categories.every(row => row.monthlySpend === 0)) return '<p>Your confirmed budget has no purchases to allocate. Move the spending slider or edit your category amounts to explore a plan.</p>'
  return `<div class="spending-guide-rows">${plan.categories.map((row, i) => {
    if(row.monthlySpend === 0) return ''
    const options = row.programme ? row.options.filter(option => option.programme === row.programme) : row.options
    const allocated = plan.status === 'ready' && row.allocation.length
    return `<article class="spending-guide-row"><div class="spending-guide-category"><h3>${escape(row.label)}</h3>${row.monthlySpend != null ? `<span>${money(row.monthlySpend)} / month</span>` : ''}${editable ? programmeSelect(row, i) : ''}</div><div class="spending-guide-use">${allocated ? row.allocation.map(part => `<div><strong>Use ${escape(part.name)}</strong><p>${money(part.annualSpend)} / year at ${rate(part.rate, part.unit)} <span class="spending-earned">→ ${escape(earnings(part))}</span></p><p class="caption">${escape(part.reason)} ${escape(part.conditions)}</p></div>`).join('') : options.map(option => {
      const first = option.cards[0]
      return `<div><strong>${row.programme ? 'Use ' : ''}${escape(first.name)}</strong><p>${rate(first.rate, option.unit)}${option.unit !== 'cashback' ? ' · ' + escape(option.label) : ''}</p>${row.programme ? `<p class="caption">${escape(first.reason)} ${escape(first.conditions)}</p>` : ''}${row.programme && first.cap ? `<p class="caption">Higher rate on up to ${money(first.cap)} / year; the plan routes spending above this cap at the next eligible rate.</p>` : ''}</div>`
    }).join('')}</div></article>`
  }).join('')}</div>`
}

export function totalsMarkup(plan) {
  if (plan?.status !== 'ready') return ''
  return `<ul class="spending-totals">${plan.totals.map(row => `<li><strong>${row.unit === 'cashback' ? money(row.earned) : number(row.earned) + ' ' + row.unit}</strong><span>${escape(row.label)} · per year, before fees</span></li>`).join('')}</ul>`
}

export function planMessage(plan) {
  if (plan?.status === 'choices_required') return 'Choose which rewards to earn for each category with spending. We keep programmes separate and count each purchase once.'
  if (plan?.status === 'ready') return 'Your annual spending plan. Rewards stay in their original currency; ongoing card fees are shown separately.'
  return 'See which card to reach for. Enter and confirm your budget to see what this plan could earn.'
}
