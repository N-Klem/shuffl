// Both screens use the same server calculator; no point-to-dollar math in the UI.
export async function fetchEstimate(cardIds, amounts, confirmed, signal) {
  const response = await fetch('/reward_estimates', {
    method: 'POST', signal,
    headers: { 'Content-Type': 'application/json', Accept: 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content },
    body: JSON.stringify({ card_ids: cardIds, amounts, confirmed })
  })
  if (!response.ok) throw new Error('Could not refresh your estimate. Please try again.')
  return response.json()
}

export function estimateMessage(estimate) {
  if (!estimate || estimate.status === 'confirmation_required') return 'Enter and confirm your eligible monthly spending to calculate cashback.'
  if (estimate.status === 'unavailable') return 'Compare the card benefits and earning conditions below. No dollar value is assigned to these benefits.'
  if (estimate.status === 'partial') return 'Cashback portion only, before fees. Spending is assigned once across supported cashback cards. Other rewards and benefits are shown separately and are not included in this dollar figure.'
  if (estimate.net == null) return 'Cashback before fees. Check the issuer’s ongoing fees before comparing net value.'
  return 'Ongoing annual scenario after card fees. Each purchase is counted once. Welcome offers and conditional credits are excluded.'
}

export function stackOverview(cards) {
  if (!cards.length) return { title: 'Your next card', detail: 'Save cards to compare their benefits and plan your wallet.' }
  if (cards.every(c => c.valueProfile?.kind === 'credit')) return { title: 'Build your credit', detail: 'Focus on responsible use, ongoing costs and credit-building features.' }
  if (cards.some(c => c.valueProfile?.estimateSupported)) return { title: 'Make spending count', detail: 'Enter your budget to explore the cashback these cards could earn.' }
  if (cards.every(c => c.valueProfile?.kind === 'travel')) return { title: 'Your travel toolkit', detail: 'Compare earning rates and travel benefits. Redemption choices determine what your points or miles are worth.' }
  return { title: 'Benefits that fit', detail: 'Compare each card’s earning categories, conditions and ongoing costs.' }
}
