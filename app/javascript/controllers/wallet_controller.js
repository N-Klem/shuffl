import { guideMarkup, totalsMarkup, planMessage, programmeSelect, earnings } from "controllers/spending_plan_helpers"
import { stackOverview } from "controllers/reward_estimate_helpers"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stage", "modal", "notice"]
  static values = { payload: Object }
  connect() {
    const root=this.element, stage=this.stageTarget, dialog=this.modalTarget, notice=this.noticeTarget;
    const wordmark=root.querySelector('[data-wallet-wordmark]').innerHTML;
    let data, cards=[], selected, view='ledger', tabName='Overview', busy=false, toastTimer;
    const escape=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    // Rounded, sign-aware — for estimates, fees, totals (whole dollars, minus before the $).
    const money=n=>{if(n==null)return 'Check issuer terms';const v=Math.round(Number(n)||0);return (v<0?'−$':'$')+Math.abs(v).toLocaleString()};
    // Exact, with the pence dropped to muted (DESIGN.md) — for tracked amounts like a statement balance.
    const exact=n=>{const v=Number(n)||0,[d,c]=Math.abs(v).toFixed(2).split('.');return (v<0?'−$':'$')+(+d).toLocaleString()+'<span class="pence">.'+c+'</span>'};
    const contribution=c=>{const rows=data.spendingPlan?.status==='ready'?data.spendingPlan.allocation.filter(row=>row.cardId===c.cardId):[];return rows.length?{...rows[0],earned:rows.reduce((sum,row)=>sum+row.earned,0)}:null};
    const date=s=>s?new Date(s+'T12:00:00').toLocaleDateString(undefined,{month:'short',day:'numeric',year:'numeric'}):'Not set';
    function accept(payload){
      data=payload;
      cards=data.cards.map(c=>({...c,name:escape(c.name),rate:escape(c.rate),perk:escape(c.perk),bonus:escape(c.bonus),description:escape(c.description),reward:0}));
      if(!cards.some(c=>c.id===selected))selected=cards[0]?.id;
    }
    function refresh(){stage.innerHTML=render()}
    function toast(text){clearTimeout(toastTimer);notice.className='toast';notice.textContent=text;toastTimer=setTimeout(()=>{notice.className='';notice.textContent=''},4500)}
    async function request(url,method,body){
      if(busy)throw new Error('Please wait for the current save.');busy=true;
      try{const response=await fetch(url,{method,headers:{'Content-Type':'application/json','Accept':'application/json','X-CSRF-Token':document.querySelector('meta[name="csrf-token"]').content},body:JSON.stringify(body)});if(!response.ok){let message='Could not save. Please try again.';try{message=(await response.json()).error||message}catch{}throw new Error(message)}accept(await response.json());refresh()}finally{busy=false}
    }
    const update=(c,values)=>request('/wallet_items/'+c.id,'PATCH',{wallet_item:values});
    function modal(title,body,submit,label='Save'){
      dialog.setAttribute("aria-label", title);
      dialog.innerHTML=`<form><h2>${title}</h2>${body}<p class="wallet-error" role="alert"></p><div class="actions"><button class="primary" type="submit">${label}</button><button type="button" data-cancel>Cancel</button></div></form>`;
      dialog.querySelector('[data-cancel]').onclick=()=>dialog.close();
      dialog.querySelector('form').onsubmit=async e=>{e.preventDefault();const button=e.submitter;button.disabled=true;try{await submit(new FormData(e.target));dialog.close()}catch(error){dialog.querySelector('[role=alert]').textContent=error.message}finally{button.disabled=false}};
      dialog.showModal();
    }
function card(c,button=false,i=0){const tag=button?'button':'div';return `<${tag} class="credit ${c.imageUrl?'has-card-image':''}" style="--metal:${c.metal};--fg:${c.fg};--i:${i}" ${button?`type="button" data-select-card="${c.id}" aria-label="Select ${c.name}" aria-pressed="${selected===c.id}"`:''}>${c.imageUrl?`<img class="card-image" src="${escape(c.imageUrl)}" alt="" decoding="async">`:wordmark}<span class="chip"></span><span class="name">${c.name}</span></${tag}>`}
function paymentTimeline() {
  const owned=cards.filter(c=>c.owned), pending=owned.filter(c=>!c.paid).sort((a,b)=>(a.due||'9999').localeCompare(b.due||'9999'));
  return `<section class="timeline wallet-payments" aria-labelledby="payments-heading"><div class="row"><div><span class="eyebrow">OWNED CARDS</span><h2 id="payments-heading">Upcoming payments</h2></div><button class="text" data-act="notifications">Reminder settings</button></div>
    <p class="timeline-intro">${pending.length?'Your next due dates, earliest first. Payments are tracked manually.':owned.length?'All tracked payments are marked as paid.':'Add an owned card to start tracking payments.'}</p>
    ${pending.length?`<ol class="wallet-timeline-list" tabindex="0" aria-label="Timeline; scroll horizontally for more cards">${pending.map(c=>`<li class="wallet-timeline-entry ${c.due&&c.due<data.today?'is-overdue':''}"><div class="timeline-date">${c.due?(c.due<data.today?'Overdue · ':c.due===data.today?'Today · ':'')+date(c.due):'Date not set'}</div><div class="timeline-card"><h3>${c.name}</h3><span class="muted">${c.balance==null?'Add your statement balance':exact(c.balance)+' statement balance'}</span></div><div class="actions"><button class="${c.due?'text':'btn-wallet'}" data-act="payment" data-item="${c.id}">${c.due?'Edit payment details':'Set payment date'}</button>${c.due&&c.balance!=null?`<button class="btn-wallet" data-act="paid" data-item="${c.id}">Mark as paid</button>`:''}</div></li>`).join('')}</ol>`:''}
    ${data.notifications?'<p class="muted">Wallet reminders are on. Dates appear here when you visit; no background notifications.</p>':''}</section>`
}
function plannedTimeline() {
  const planned=cards.filter(c=>!c.owned).sort((a,b)=>(a.apply||'9999').localeCompare(b.apply||'9999'));
  return `<section class="timeline wallet-planned" aria-labelledby="planned-heading"><div class="row"><div><span class="eyebrow">PLANNED CARDS</span><h2 id="planned-heading">Your application plan</h2></div><button class="text" data-act="find">Add a planned card</button></div><p class="timeline-intro">Choose when you'd like to apply. These are your own target dates.</p>${planned.length?`<ol class="wallet-timeline-list" tabindex="0" aria-label="Timeline; scroll horizontally for more cards">${planned.map(c=>`<li class="wallet-timeline-entry"><div class="timeline-date">${c.apply?date(c.apply):'Choose a date'}</div><div class="timeline-card"><h3>${c.name}</h3>${c.apply&&c.apply<data.today?'<span class="muted">Target date passed — review your plan</span>':''}</div><div class="actions"><button class="btn-wallet" data-schedule="${c.id}">${c.apply?'Change date':'Set application date'}</button><button class="text" data-act="own" data-item="${c.id}">I got this card</button></div></li>`).join('')}</ol>`:'<p class="wallet-empty-note">No planned cards yet. Add one when you find a card you like.</p>'}</section>`
}
function render(){const c=cards.find(x=>x.id===selected),owned=cards.filter(x=>x.owned),overview=stackOverview(owned.length?owned:cards),plan=data.spendingPlan;return `<main class="${view}"><div class="heading"><div><span class="eyebrow">Your cards. Working together.</span><h1>my <span class="keyword-emphasis">wallet</span></h1></div><div class="summary"><div><span class="muted">${plan?.status==='ready'?'Your yearly rewards · owned':'Your wallet focus'}</span><span class="number benefit-heading">${plan?.status==='ready'?'Your spending, rewarded':escape(overview.title)}</span>${totalsMarkup(plan)}</div><div><span class="muted">Ongoing yearly card fees · owned</span><span class="number fee">${money(plan?.fees)}</span></div></div></div>
${owned.some(c=>c.spendingSupported)?`<section class="spending-guide" aria-labelledby="wallet-guide-title"><div class="row"><h2 id="wallet-guide-title">Which card, when?</h2><button class="text" data-act="plan">${data.spendingConfirmed?'Edit spending plan':'Plan my spending'}</button></div><p class="muted">${escape(planMessage(plan))}</p>${plan?.netCashback!=null?`<p>Modeled cashback after all owned-card fees: <strong>${money(plan.netCashback)}</strong></p>`:''}${guideMarkup(plan,false)}<details><summary>How this plan works</summary><p class="muted">${escape(plan?.assumptions)}</p><p class="muted">Only modeled owned cards receive spending. Specialist benefits remain in the card details; Planned cards are excluded.</p></details></section>`:''}
${paymentTimeline()}
<div class="row collection-heading"><h2>Your collection <span class="muted">${cards.length} cards</span></h2><div class="actions"><button class="btn-wallet" data-act="find">Find more cards</button></div></div>
<div class="workspace"><aside class="shelves">${[true,false].map(own=>`<section class="shelf ${own?'':'planned'}"><div class="row"><h2>${own?'Owned':'Planned'}</h2><span class="badge">${cards.filter(c=>c.owned===own).length}</span></div><div class="fan" style="--extra:${Math.max(0,cards.filter(c=>c.owned===own).length-2)}">${cards.filter(c=>c.owned===own).map((c,i)=>card(c,true,i)).join('')||'<p class="wallet-empty-note">'+(own?'Cards you have will appear here.':'Cards you are considering will appear here.')+'</p>'}</div></section>`).join('')}</aside><section class="detail" id="detail">${c?details(c):'<div class="empty"><h2>Your wallet starts here.</h2><p>Add a card to Planned to start building your collection.</p><button class="btn-wallet" data-act="find">Find more cards</button></div>'}</section></div>
${plannedTimeline()}
<p class="demo">Recorded rates and conditions are on each card’s detail page. Reward estimates use confirmed eligible spending and supported schedules. Cashback, points and miles stay separate. Conditional benefits have no assumed dollar value. Planned cards are excluded. Tracking is manual.</p></main>`}
function details(c){
  const days=c.deadline?Math.ceil((new Date(c.deadline+'T12:00:00')-new Date(data.today+'T12:00:00'))/86400000):null;
  const active=c.owned&&(tabName!=='Bonus'||c.bonus||c.goal||c.deadline)?tabName:'Overview';
  return `<div class="detail-top"><div><span class="eyebrow">${c.owned?'In your wallet':'Planned card'}</span><h2>${c.name}</h2></div><div id="selected-art">${card(c)}</div></div>
  ${c.owned?`<div class="tabs" role="tablist" aria-label="Card details">${['Overview','Payments',...(c.bonus||c.goal||c.deadline?['Bonus']:[])].map(t=>`<button type="button" role="tab" id="wallet-tab-${t}" aria-controls="wallet-detail-panel" aria-selected="${active===t}" tabindex="${active===t?'0':'-1'}" data-tab="${t}" class="${active===t?'active':''}">${t}</button>`).join('')}</div>`:''}
  <div class="details-body" id="wallet-detail-panel" ${c.owned?`role="tabpanel" aria-labelledby="wallet-tab-${active}" tabindex="0"`:''}>
  ${active==='Overview'?`<p>${escape(c.valueProfile.title)}</p><ul>${c.perks.map(p=>`<li>${escape(p)}</li>`).join('')}</ul><a class="text" href="${c.url}">Explore this card ↗</a><div class="section stats"><div><span class="muted">${c.owned&&contribution(c)!=null?'Rewards from your spending / year':escape(c.valueProfile.label)}</span><strong class="${c.owned&&contribution(c)!=null?'reward':'benefit-heading'}">${c.owned&&contribution(c)!=null?escape(earnings(contribution(c))):escape(c.valueProfile.value)}</strong></div>${c.valueProfile.label!=='Annual fee'||contribution(c)!=null?`<div><span class="muted">Annual fee</span><strong class="fee">${money(c.fee)}</strong></div>`:''}</div><p class="muted">${escape(c.valueProfile.conditions||c.valueProfile.detail)}</p>`:''}
  ${active==='Payments'?`<div class="section"><div class="row"><h3>Statement payment</h3><span class="badge">${c.paid?'Paid ✓':c.due?'Due '+date(c.due):'No due date'}</span></div><span class="number">${c.balance==null?'—':exact(c.balance)}</span><p class="muted">Statement balance · manually tracked</p><div class="actions"><button class="btn-wallet" data-act="paid" ${c.paid||c.balance==null||!c.due?'disabled':''}>${c.paid?'Marked as paid ✓':'Mark as paid'}</button><button class="text" data-act="payment">Edit payment details</button></div></div>`:''}
  ${active==='Bonus'?`<div class="section"><div class="row"><h3>${c.bonus||'Your offer tracking'}</h3><span class="muted bonus-deadline">${days==null?'No deadline':days<0?'Deadline passed':days+' days left'}</span></div><p>${c.goal?`${money(Math.max(0,c.goal-c.spent))} remaining of ${money(c.goal)}.`:'Add the spending requirement and deadline from your offer.'}</p><div class="progress"><span style="width:${c.goal?Math.min(100,c.spent/c.goal*100):0}%"></span></div><div class="row"><span class="muted">${money(c.spent)} of ${c.goal?money(c.goal):'—'}</span><button class="btn-wallet" data-act="total">${c.deadline?'Edit bonus tracking':'Set deadline'}</button></div></div>`:''}
  </div><div class="wallet-detail-actions">${!c.owned?'<div class="actions"><button class="btn-wallet" data-act="own">I got this card</button><button class="text" data-act="swap">Swap card</button></div>':''}<button class="text" data-act="remove">Remove this card</button></div>`
}
    const field=(label,name,value,type='number')=>`<label>${label}<input name="${name}" type="${type}" ${type==='number'?'min="0" step="0.01" max="9999999999"':''} value="${escape(value??'')}"></label>`;
    const tracking=c=>field('Opening date','opened_on',c.opened,'date')+field('Bonus deadline','bonus_deadline',c.deadline,'date')+field('Required qualifying spending ($)','bonus_target',c.goal)+field('Total qualifying spending so far ($)','bonus_spend',c.spent);
    const values=form=>Object.fromEntries([...form].map(([k,v])=>[k,v===''?null:v]));
    const chooseCard=(swap,c)=>{
      const occupied=new Set(cards.map(x=>x.cardId));
      const owned=cards.filter(x=>x.owned);
      const candidates=data.catalogue.filter(x=>!occupied.has(x.id));
      if(!candidates.length){toast('Your wallet already includes all available cards.');return}
      modal(swap?'A different fit':'Complement your wallet',`<p>Compare each card’s benefits, earning categories and ongoing fees.</p><label>Choose a card<select name="card_id">${candidates.map(x=>`<option value="${x.id}">${escape(x.name)} · ${money(x.fee)} annual fee</option>`).join('')}</select></label><div data-candidate></div>`,async f=>{if(swap)await update(c,{card_id:f.get('card_id')});else await request('/wallet_items','POST',{card_id:f.get('card_id')});toast(swap?'Planned card swapped':'Card added to Planned')},swap?'Swap card':'Add to Planned');
      const select=dialog.querySelector('select');const describe=()=>{const x=candidates.find(x=>x.id===+select.value);dialog.querySelector('[data-candidate]').innerHTML=`<p>${escape(x.valueProfile.title)}</p><p><strong>${escape(x.valueProfile.value)}</strong> · ${escape(x.valueProfile.label)}<br><span class="fee">Annual fee: ${money(x.fee)}</span></p><p class="muted">Review the card’s recorded terms and issuer sources. This comparison does not assess approval eligibility.</p>`};select.onchange=describe;describe();
    };
    const onClick=async e=>{
      const b=e.target.closest('button');if(!b||busy)return;
      const c=cards.find(x=>x.id===(b.dataset.item?+b.dataset.item:selected));
      try{
        if(b.dataset.selectCard){selected=+b.dataset.selectCard;tabName='Overview';refresh();stage.querySelector(`[data-select-card="${selected}"]`)?.focus({preventScroll:true});return}
        if(b.dataset.tab){tabName=b.dataset.tab;refresh();stage.querySelector(`[data-tab="${tabName}"]`)?.focus({preventScroll:true});return}
        if(b.dataset.schedule){const item=cards.find(x=>x.id===+b.dataset.schedule);modal('Plan your application',field('Target application date','apply_on',item.apply,'date'),f=>update(item,values(f)));return}
        switch(b.dataset.act){
          case 'remove':modal('Remove this card?',`<p>Remove ${c.name} from ${c.owned?'Owned':'Planned'} in Shuffl? Its saved dates and tracking details will also be removed.</p><p>This does not close your credit-card account or cancel an application.</p>`,async()=>{await request('/wallet_items/'+c.id,'DELETE');toast('Card removed from your wallet')},'Remove card');dialog.querySelector('[type="submit"]').className='btn-wallet';dialog.querySelector('[data-cancel]').focus();break;
          case 'paid':await update(c,{paid:true});toast('Payment marked as paid');break;
          case 'payment':modal('Payment details',`<p>Enter the details from your latest statement. Saving starts a new unpaid tracking period.</p>${field('Statement balance ($)','statement_balance',c.balance)}${field('Payment due date','payment_due_on',c.due,'date')}`,f=>update(c,{...values(f),paid:false}));break;
          case 'total':modal('Track your welcome bonus',`<p>Use the exact requirement and deadline from your card offer.</p>${tracking(c)}`,f=>update(c,values(f)));break;
          case 'own':modal('Make it official',`<p>Move ${c.name} to Owned. Add bonus details if your offer has a welcome bonus.</p>${tracking(c)}`,f=>update(c,{...values(f),status:'owned'}),'Add to Owned');break;
          case 'swap':chooseCard(true,c);break;
          case 'find':chooseCard(false,c);break;
          case 'notifications':modal('Your wallet reminders',`<p>Show payment and bonus reminders whenever you visit My Wallet.</p><label><input style="display:inline;width:auto" type="checkbox" name="notifications" ${data.notifications?'checked':''}> Enable wallet reminders</label><p class="muted">Email and background push delivery are not available yet.</p>`,f=>request('/wallet_items/preferences','PATCH',{preferences:{notifications:f.has('notifications')}}),'Save preferences');break;
          case 'plan':{
            const owned=cards.filter(x=>x.owned);
            modal('Plan my spending',`<p>Enter your own monthly budget. Review every amount and category, including any previously saved plan.</p>${data.categories.map((label,i)=>`<label class="allocation"><span>${escape(label)}</span><input aria-label="${escape(label)} monthly spending" name="amount${i}" type="number" min="0" max="1000000" step="1" required value="${data.amounts[i]}"></label>${programmeSelect(data.spendingPlan.categories[i],i,'wallet-programme')}`).join('')}<p data-budget></p><p class="muted">${escape(data.spendingGuidance)}</p><label><input class="spending-checkbox" type="checkbox" name="confirmed" required> I confirm these eligible amounts, have checked category eligibility for my owned cards, and will pay in full and on time.</label><p class="muted">A full-year scenario with unused caps. Welcome bonuses, conditional credits and planned cards are excluded.</p>`,async f=>{await request('/wallet_items/preferences','PATCH',{preferences:{amounts:data.categories.map((_,i)=>+f.get('amount'+i)),spending_confirmed:f.has('confirmed'),reward_programmes:data.categories.map((_,i)=>f.get('programme'+i)||'')}});toast('Spending plan saved')},'Confirm spending');
            const calculate=()=>{let total=0;data.categories.forEach((_,i)=>{const value=+dialog.querySelector(`[name=amount${i}]`).value;total+=value;const choice=dialog.querySelector(`[name=programme${i}]`);if(choice)choice.required=value>0 });dialog.querySelector('[data-budget]').textContent='Monthly total: '+money(total)};
            dialog.querySelectorAll('input').forEach(input=>input.oninput=calculate);calculate();break;
          }
        }
      }catch(error){toast(error.message)}
    };
    const onKeydown=e=>{const tab=e.target.closest('[data-tab]');if(!tab||!['ArrowLeft','ArrowRight','Home','End'].includes(e.key))return;e.preventDefault();const activeCard=cards.find(c=>c.id===selected),names=['Overview','Payments',...(activeCard?.bonus||activeCard?.goal||activeCard?.deadline?['Bonus']:[])],i=names.indexOf(tabName);tabName=e.key==='Home'?names[0]:e.key==='End'?names[names.length-1]:names[(i+(e.key==='ArrowRight'?1:names.length-1))%names.length];refresh();stage.querySelector(`[data-tab="${tabName}"]`)?.focus()};
    accept(this.payloadValue);refresh();stage.addEventListener('click',onClick);stage.addEventListener('keydown',onKeydown);
    const onAssistantSave=event=>{if(event.detail.wallet){accept(event.detail.wallet);refresh()}};
    window.addEventListener('assistant:wallet-updated',onAssistantSave);
    this.cleanup=()=>{window.removeEventListener('assistant:wallet-updated',onAssistantSave);stage.removeEventListener('click',onClick);stage.removeEventListener('keydown',onKeydown);clearTimeout(toastTimer);dialog.close()};
  }
  disconnect(){this.cleanup?.()}
}
