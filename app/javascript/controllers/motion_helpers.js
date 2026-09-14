const reducedMotion = () => matchMedia('(prefers-reduced-motion: reduce)').matches

// Use the same card image at both ends of an in-page detail transition.
export function revealCard(source, update, destination) {
  if (!source || reducedMotion() || !document.startViewTransition) { update(); return }
  const name = 'shuffl-selected-card'
  source.style.viewTransitionName = name
  let target
  const transition = document.startViewTransition(() => {
    source.style.viewTransitionName = ''
    update()
    target = destination()
    if (target) target.style.viewTransitionName = name
  })
  transition.finished.catch(() => {}).finally(() => {
    source.style.viewTransitionName = ''
    if (target) target.style.viewTransitionName = ''
  })
}

// Only celebrate after the server confirms a save; never delay the request.
export async function gatherCards(elements, button) {
  if (reducedMotion() || !button?.isConnected) return
  const end = button.getBoundingClientRect()
  await Promise.all([...elements].slice(0,5).map(async (element, index) => {
    const start = element.getBoundingClientRect()
    if (!start.width || start.bottom < 0 || start.top > innerHeight) return
    const card = document.createElement('div')
    const style = getComputedStyle(element)
    Object.assign(card.style, {
      position:'fixed',left:start.left+'px',top:start.top+'px',width:start.width+'px',height:start.height+'px',
      borderRadius:'9px',background:style.getPropertyValue('--metal') || style.getPropertyValue('--card-ink') || '#601020',
      border:'1px solid #ffffff88',boxShadow:'0 8px 20px #0002',pointerEvents:'none',zIndex:1200
    })
    card.setAttribute('aria-hidden','true')
    // Inside an open dialog, stay in the browser's top layer.
    ;(element.closest('dialog') || document.body).append(card)
    try {
      await card.animate([
        {transform:'translate(0,0) rotate(0deg)',opacity:.85},
        {transform:`translate(${end.left+end.width/2-start.left-start.width/2}px,${end.top+end.height/2-start.top-start.height/2}px) rotate(${index*5-10}deg) scale(.18)`,opacity:0}
      ],{duration:1200,delay:index*100,easing:'cubic-bezier(.45,0,.25,1)',fill:'forwards'}).finished
    } catch {} finally {card.remove()}
  }))
}
