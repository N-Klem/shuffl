import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stage", "modal", "notice"]
  static values = { payload: Object }
  connect() {
    const root=this.element, stage=this.stageTarget, dialog=this.modalTarget, notice=this.noticeTarget;
    let data, cards=[], selected, view='ledger', tabName='Overview', busy=false, animation, flying, toastTimer;
    const escape=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const money=n=>'$'+Number(n||0).toLocaleString(undefined,{maximumFractionDigits:2});
    const date=s=>s?new Date(s+'T12:00:00').toLocaleDateString(undefined,{month:'short',day:'numeric',year:'numeric'}):'Not set';
    function accept(payload){
      data=payload;
      cards=data.cards.map(c=>({...c,name:escape(c.name),rate:escape(c.rate),perk:escape(c.perk),bonus:escape(c.bonus),description:escape(c.description),reward:0}));
      data.amounts.forEach((amount,i)=>{const best=cards.filter(c=>c.owned).sort((a,b)=>b.rates[i]-a.rates[i])[0];if(best)best.reward+=amount*12*best.rates[i]/100});
      cards.filter(c=>!c.owned).forEach(c=>{c.reward=data.amounts.reduce((sum,amount,i)=>sum+amount*12*c.rates[i]/100,0)});
      if(!cards.some(c=>c.id===selected))selected=cards[0]?.id;
    }
    function reminders(){if(!data.notifications)return '';const lines=cards.filter(c=>c.owned).flatMap(c=>[!c.paid&&c.due?`${c.name}: payment due ${date(c.due)}`:null,c.deadline&&c.goal>c.spent?`${c.name}: bonus deadline ${date(c.deadline)}`:null]).filter(Boolean);return `<section class="notice-list"><h3>Your reminders</h3>${lines.length?lines.map(t=>`<p>${t}</p>`).join(''):'No outstanding payment or bonus reminders.'}</section>`}
    function refresh(){stage.innerHTML=render()}
    function toast(text){clearTimeout(toastTimer);notice.className='toast';notice.textContent=text;toastTimer=setTimeout(()=>{notice.className='';notice.textContent=''},4500)}
    async function request(url,method,body){
      if(busy)throw new Error('Please wait for the current save.');busy=true;
      try{const response=await fetch(url,{method,headers:{'Content-Type':'application/json','Accept':'application/json','X-CSRF-Token':document.querySelector('meta[name="csrf-token"]').content},body:JSON.stringify(body)});if(!response.ok){let message='Could not save. Please try again.';try{message=(await response.json()).error||message}catch{}throw new Error(message)}accept(await response.json());refresh()}finally{busy=false}
    }
    const update=(c,values)=>request('/wallet_items/'+c.id,'PATCH',{wallet_item:values});
    function modal(title,body,submit,label='Save'){
      dialog.innerHTML=`<form><h2>${title}</h2>${body}<p class="wallet-error" role="alert"></p><div class="actions"><button class="primary" type="submit">${label}</button><button type="button" data-cancel>Cancel</button></div></form>`;
      dialog.querySelector('[data-cancel]').onclick=()=>dialog.close();
      dialog.querySelector('form').onsubmit=async e=>{e.preventDefault();const button=e.submitter;button.disabled=true;try{await submit(new FormData(e.target));dialog.close()}catch(error){dialog.querySelector('[role=alert]').textContent=error.message}finally{button.disabled=false}};
      dialog.showModal();
    }
function card(c,button=false,i=0){return `<${button?'button':'div'} class="credit" style="--metal:${c.metal};--fg:${c.fg};--i:${i}" ${button?`data-card="${c.id}" aria-label="Select ${c.name}"`:''}><span class="brand">shuffl</span><span class="chip"></span><span class="name">${c.name}</span></${button?'button':'div'}>`}
function render(){const c=cards.find(x=>x.id===selected),owned=cards.filter(x=>x.owned);return `<main class="${view}"><div class="heading"><div><span class="eyebrow">Your cards. Working together.</span><h1>my wallet</h1></div><div class="summary"><div><span class="muted">Estimated annual rewards · owned</span><span class="number reward">${money(owned.reduce((a,c)=>a+c.reward,0))}</span></div><div><span class="muted">Annual fees · owned</span><span class="number fee">${money(owned.reduce((a,c)=>a+c.fee,0))}</span></div></div></div><div class="timeline"><div class="row"><h3 style="margin:0">Your next moves</h3><button class="text" data-act="notifications">${data.notifications?'Notifications on ✓':'Send me notifications ↗'}</button></div><div class="steps"><div class="step"><small>TODAY</small>Enjoy your owned cards</div>${cards.filter(c=>!c.owned).map((c,i)=>`<div class="step"><small>${c.apply?date(c.apply):'DATE NOT SET'} · PLANNED</small>${c.name}<br><button class="text" data-schedule="${c.id}">Set application date</button></div>`).join('')}<div class="step"><small>LOOKING AHEAD</small>Review your rewards</div></div></div><div class="row" style="margin-bottom:24px"><h2>Your collection <span class="muted">${cards.length} cards</span></h2><div class="actions"><button data-act="find">Find more cards ↗</button><button class="primary" data-act="plan">Plan my spending</button></div></div>${reminders()}<div class="workspace"><aside class="shelves">${[true,false].map(own=>`<section class="shelf ${own?'':'planned'}"><div class="row"><h2>${own?'Owned':'Planned'}</h2><span class="badge">${cards.filter(c=>c.owned===own).length} cards</span></div><div class="fan" style="--extra:${Math.max(0,cards.filter(c=>c.owned===own).length-2)}">${cards.filter(c=>c.owned===own).map((c,i)=>card(c,true,i)).join('') || '<p class="empty">'+(own?'Mark a planned card as owned when it arrives.':'Find a card to plan your next move.')+'</p>'}</div><small>${own?'The cards in your everyday rotation.':'Your next chapter. Ready when you are.'}</small></section>`).join('')}</aside><section class="detail" id="detail">${c?details(c):'<div class="empty"><h2>Your wallet starts here.</h2><p>Add a recommended card to Planned to start building your collection.</p><button data-act="find">Find more cards ↗</button></div>'}</section></div><p class="demo">Estimates use Shuffl’s illustrative catalogue and your spending plan. Each category counts once on the best-rate owned card. Points valued at 1¢; excludes bonuses, interest and caps. Tracking is manual.</p></main>`}
function details(c){const days=c.deadline?Math.ceil((new Date(c.deadline+'T12:00:00')-new Date(data.today+'T12:00:00'))/86400000):null;return `<div class="detail-top"><div><span class="eyebrow">${c.owned?'In your wallet':'On your horizon'}</span><h2>${c.name}</h2><div class="perks"><span class="perk">${c.rate}</span><span class="perk">${c.perk}</span></div></div><div id="selected-art">${card(c)}</div></div>${view==='gallery'?`<div class="tabs">${['Overview','Payments','Bonus'].map(t=>`<button data-tab="${t}" class="${tabName===t?'active':''}">${t}</button>`).join('')}</div>`:''}<p>${c.description||''}</p><a href="${c.url}">Explore this card ↗</a><div class="details-body">${view==='ledger'||tabName==='Overview'?`<div class="section stats"><div><span class="muted">Annual rewards</span><strong class="reward">${money(c.reward)}</strong></div><div><span class="muted">Annual fee</span><strong class="fee">${money(c.fee)}</strong></div><div><span class="muted">After annual fee</span><strong class="${c.reward-c.fee>=0?'reward':'fee'}">${money(c.reward-c.fee)}</strong></div></div>`:''}${c.owned&&(view==='ledger'||tabName==='Payments')?`<div class="section"><div class="row"><h3>Stay on top of payments</h3><span class="badge">${c.paid?'Paid ✓':(c.due?'Due '+date(c.due):'Set payment date')}</span></div><div class="row"><div><span class="number">${c.balance==null?'—':money(c.balance)}</span><span class="muted">Statement balance · manually tracked</span></div><button data-act="paid" ${c.paid||c.balance==null||!c.due?'disabled':''}>${c.paid?'Marked as paid ✓':'Mark as paid'}</button></div><button class="text" data-act="payment">Edit payment details</button></div>`:''}${view==='ledger'||tabName==='Bonus'?`<div class="section"><div class="row"><h3 class="reward">${c.bonus} welcome bonus</h3><span class="badge">${c.owned?(days==null?'Set deadline':days<0?'Deadline passed':days+' days left'):'Starts when opened'}</span></div><p>${c.goal?`${money(Math.max(0,c.goal-c.spent))} remaining of ${money(c.goal)}${days>0?' · '+money(Math.ceil(Math.max(0,c.goal-c.spent)/days*7))+' per week to reach your target.':'.'}`:'Enter the spending requirement and deadline from your offer to start tracking.'}</p><div class="progress"><span style="width:${(c.goal?Math.min(100,c.spent/c.goal*100):0)}%"></span></div><div class="row"><span class="muted">${money(c.spent)} of ${c.goal?money(c.goal):'—'}</span>${c.owned?'<button class="text" data-act="total">Update spending total</button>':''}</div></div>`:''}${!c.owned?'<div class="section actions"><button class="primary" data-act="own">I got this card</button><button data-act="swap">Swap card</button></div>':''}</div>`}
    const field=(label,name,value,type='number')=>`<label>${label}<input name="${name}" type="${type}" ${type==='number'?'min="0" step="0.01" max="9999999999"':''} value="${escape(value??'')}"></label>`;
    const tracking=c=>field('Opening date','opened_on',c.opened,'date')+field('Bonus deadline','bonus_deadline',c.deadline,'date')+field('Required qualifying spending ($)','bonus_target',c.goal)+field('Total qualifying spending so far ($)','bonus_spend',c.spent);
    const values=form=>Object.fromEntries([...form].map(([k,v])=>[k,v===''?null:v]));
    const chooseCard=(swap,c)=>{
      const occupied=new Set(cards.map(x=>x.cardId));
      const owned=cards.filter(x=>x.owned);
      const candidates=data.catalogue.filter(x=>!occupied.has(x.id)).map(x=>({...x,lift:data.amounts.reduce((sum,amount,i)=>sum+amount*12*Math.max(0,x.rates[i]-Math.max(0,...owned.map(o=>o.rates[i])))/100,0)-x.fee})).sort((a,b)=>b.lift-a.lift);
      if(!candidates.length){toast('Your wallet already includes all available cards.');return}
      modal(swap?'A different fit':'Complement your wallet',`<p>Ranked by estimated additional rewards after fees, using your current spending and owned cards.</p><label>Choose a card<select name="card_id">${candidates.map(x=>`<option value="${x.id}">${escape(x.name)} · ${x.lift>=0?'+':''}${money(x.lift)} / year</option>`).join('')}</select></label><div data-candidate></div>`,async f=>{if(swap)await update(c,{card_id:f.get('card_id')});else await request('/wallet_items','POST',{card_id:f.get('card_id')});toast(swap?'Planned card swapped':'Card added to Planned')},swap?'Swap card':'Add to Planned');
      const select=dialog.querySelector('select');const describe=()=>{const x=candidates.find(x=>x.id===+select.value);dialog.querySelector('[data-candidate]').innerHTML=`<p>${escape(x.use)}</p><p><span class="reward">Potential additional rewards: ${money(x.lift+x.fee)}</span><br><span class="fee">Annual fee: ${money(x.fee)}</span></p><p class="muted">Based on the sample catalogue. This comparison does not assess approval eligibility.</p>`};select.onchange=describe;describe();
    };
    const onClick=async e=>{
      const b=e.target.closest('button');if(!b)return;
      const c=cards.find(x=>x.id===selected);
      try{
        if(b.dataset.card){
          animation?.cancel();flying?.remove();
          const rect=b.getBoundingClientRect(),copy=b.cloneNode(true);selected=+b.dataset.card;refresh();
          const art=root.querySelector('#selected-art'),dest=art.querySelector('.credit').getBoundingClientRect();
          if(!matchMedia('(prefers-reduced-motion: reduce)').matches){
            copy.classList.add('fly');Object.assign(copy.style,{left:rect.left+'px',top:rect.top+'px',width:rect.width+'px',height:rect.height+'px',opacity:1});root.append(copy);flying=copy;art.style.opacity=0;
            animation=copy.animate([{transform:'translate(0,0) rotate(-10deg)'},{transform:`translate(${dest.left-rect.left}px,${dest.top-rect.top}px) rotate(-4deg) scale(${dest.width/rect.width})`}],{duration:650,easing:'cubic-bezier(.23,1,.32,1)',fill:'forwards'});
            animation.onfinish=()=>{copy.remove();art.style.opacity=1};
          }return;
        }
        if(b.dataset.schedule){const item=cards.find(x=>x.id===+b.dataset.schedule);modal('Plan your application',field('Target application date','apply_on',item.apply,'date'),f=>update(item,values(f)));return}
        switch(b.dataset.act){
          case 'paid':await update(c,{paid:true});toast('Payment marked as paid');break;
          case 'payment':modal('Payment details',`<p>Enter the details from your latest statement. Saving starts a new unpaid tracking period.</p>${field('Statement balance ($)','statement_balance',c.balance)}${field('Payment due date','payment_due_on',c.due,'date')}`,f=>update(c,{...values(f),paid:false}));break;
          case 'total':modal('Track your welcome bonus',`<p>Use the exact requirement and deadline from your card offer.</p>${tracking(c)}`,f=>update(c,values(f)));break;
          case 'own':modal('Make it official',`<p>Move ${c.name} to Owned. Add bonus details if your offer has a welcome bonus.</p>${tracking(c)}`,f=>update(c,{...values(f),status:'owned'}),'Add to Owned');break;
          case 'swap':chooseCard(true,c);break;
          case 'find':chooseCard(false,c);break;
          case 'notifications':modal('Your wallet reminders',`<p>Show payment and bonus reminders whenever you visit My Wallet.</p><label><input style="display:inline;width:auto" type="checkbox" name="notifications" ${data.notifications?'checked':''}> Enable wallet reminders</label><p class="muted">Email and background push delivery are not available yet.</p>`,f=>request('/wallet_items/preferences','PATCH',{preferences:{notifications:f.has('notifications')}}),'Save preferences');break;
          case 'plan':{
            const owned=cards.filter(x=>x.owned);
            modal('Plan my spending',`<p>Allocate the budget you already spend. The highest-rate owned card is shown for each category.</p>${data.categories.map((label,i)=>`<label class="allocation"><span>${escape(label)}</span><span data-best="${i}"></span><input aria-label="${escape(label)} monthly spending" name="amount${i}" type="number" min="0" max="1000000" step="1" required value="${data.amounts[i]}"></label>`).join('')}<p data-budget></p><p class="muted">Bonus requirements are tracked separately; check the remaining spend and deadline before allocating purchases. Unknown category rates are treated as zero.</p>`,async f=>{await request('/wallet_items/preferences','PATCH',{preferences:{amounts:data.categories.map((_,i)=>+f.get('amount'+i))}});toast('Spending plan saved')},'Save plan');
            const calculate=()=>{let total=0;data.categories.forEach((_,i)=>{total+=+dialog.querySelector(`[name=amount${i}]`).value;const best=owned.slice().sort((a,b)=>b.rates[i]-a.rates[i])[0];dialog.querySelector(`[data-best="${i}"]`).textContent=best?data.cards.find(x=>x.id===best.id).name:'Add an owned card'});dialog.querySelector('[data-budget]').textContent='Monthly total: '+money(total)};
            dialog.querySelectorAll('input').forEach(input=>input.oninput=calculate);calculate();break;
          }
        }
      }catch(error){toast(error.message)}
    };
    accept(this.payloadValue);refresh();stage.addEventListener('click',onClick);
    this.cleanup=()=>{stage.removeEventListener('click',onClick);clearTimeout(toastTimer);animation?.cancel();flying?.remove();dialog.close()};
  }
  disconnect(){this.cleanup?.()}
}
