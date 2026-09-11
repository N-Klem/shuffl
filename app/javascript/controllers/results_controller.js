import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { payload: Object, quizId: Number, saveUrl: String }

  connect() {
    if (this.initialized) return
    this.initialized = true
    const root = this.element
const data=this.payloadValue;
const escape=value=>String(value??'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const catalog=data.cards.map(c=>({...c,name:escape(c.name),role:escape(c.role),use:escape(c.use),perks:c.perks.map(escape)}));
const selected=[...data.selected],kept=selected.map(()=>false),spend=root.querySelector('#spend');
if(!selected.length){root.querySelector('#cards').innerHTML='<p>No cards are available yet. <a href="/quiz_responses/new">Retake the quiz</a> after cards have been added.</p>';root.querySelector('#save-stack').disabled=true;root.querySelector('.summary').hidden=true;return;}

const money=n=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0}).format(n);
const amounts=[...data.amounts],categoryNames=data.categories;
spend.value=amounts.reduce((a,b)=>a+b,0);
function distribution(){
  const rewards=selected.map(()=>0),allocated=selected.map(()=>0);
  amounts.forEach((amount,category)=>{
    let winner=0;
    selected.forEach((id,i)=>{if(catalog[id].rates[category]>catalog[selected[winner]].rates[category])winner=i;});
    allocated[winner]+=amount;
    rewards[winner]+=amount*12*catalog[selected[winner]].rates[category]/100;
  });
  return {rewards,allocated};
}
const allocation=c=>distribution().allocated[selected.indexOf(catalog.indexOf(c))]||0;
const reward=c=>distribution().rewards[selected.indexOf(catalog.indexOf(c))]||0;
const cents=n=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',minimumFractionDigits:2,maximumFractionDigits:2}).format(n);
let savedSnapshot=null;
const snapshot=()=>JSON.stringify({selected:[...selected],kept:[...kept],amounts:[...amounts]});
function syncSave(){const same=savedSnapshot===snapshot();root.querySelector('#save-stack').textContent=same?'Stack saved':'Save this stack';root.querySelector('#save-status').textContent=same?'Saved to My Wallet.':savedSnapshot?'You have unsaved changes.':'Save these cards to My Wallet.';}
function paintRange(input){const percent=Number(input.value)/Number(input.max)*100;input.style.background='linear-gradient(to right,var(--wine) '+percent+'%,#e8e8e8 '+percent+'%)';}
root.querySelector('#category-sliders').innerHTML=categoryNames.map((name,i)=>'<div class="category"><div class="label-row"><label for="category-'+i+'">'+name+'</label><output id="category-value-'+i+'" for="category-'+i+'"></output></div><input type="range" id="category-'+i+'" data-category="'+i+'" min="0" max="10000" step="1"></div>').join('');
const storageKey='shuffl-results-'+this.quizIdValue;
const persist=()=>{try{sessionStorage.setItem(storageKey,snapshot());}catch{}};
const saveUrl=this.saveUrlValue,quizId=this.quizIdValue;
root.querySelector('#save-stack').addEventListener('click',async()=>{
  const button=root.querySelector('#save-stack'),state=snapshot();
  persist();button.disabled=true;button.textContent='Saving…';
  try{
    const response=await fetch(saveUrl,{method:'POST',headers:{'Content-Type':'application/json','Accept':'application/json','X-CSRF-Token':window.document.querySelector('meta[name="csrf-token"]').content},body:JSON.stringify({quiz_response_id:quizId,card_ids:selected.map(i=>catalog[i].id)})});
    const result=await response.json();
    if(response.status===401){root.querySelector('#save-status').innerHTML='<a href="'+result.sign_in_url+'">Sign in to save this stack</a>. Your choices will be here when you return.';button.textContent='Save this stack';}
    else if(response.ok){savedSnapshot=state;syncSave();if(state===snapshot())root.querySelector('#save-status').innerHTML='Saved. <a href="'+result.wallet_url+'">View My Wallet</a>';}
    else throw new Error(result.error||'Could not save this stack.');
  }catch{root.querySelector('#save-status').textContent='Could not save this stack. Please try again.';button.textContent='Save this stack';}
  finally{button.disabled=false;}
});
try{
  const stored=JSON.parse(sessionStorage.getItem(storageKey));
  if(stored&&stored.selected?.length===selected.length&&new Set(stored.selected).size===selected.length&&stored.selected.every(id=>Number.isInteger(id)&&catalog[id])&&stored.kept?.length===selected.length&&stored.kept.every(v=>typeof v==='boolean')&&stored.amounts?.length===amounts.length&&stored.amounts.every(v=>Number.isFinite(v)&&v>=0)&&stored.amounts.reduce((a,b)=>a+b,0)<=10000){
    selected.splice(0,selected.length,...stored.selected);kept.splice(0,kept.length,...stored.kept);amounts.splice(0,amounts.length,...stored.amounts);spend.value=amounts.reduce((a,b)=>a+b,0);
  }
}catch{}
root.querySelector('#category-sliders').addEventListener('input',e=>{if(!e.target.matches('[data-category]'))return;const i=Number(e.target.dataset.category),remaining=10000-amounts.reduce((sum,n,j)=>sum+(i===j?0:n),0);amounts[i]=Math.min(Number(e.target.value),remaining);spend.value=amounts.reduce((a,b)=>a+b,0);update();});
function renderCards(){root.querySelector('#cards').innerHTML=selected.map((id,i)=>{const c=catalog[id];return '<article class="recommendation" aria-label="'+c.name+'"><div class="art-column"><a class="card-link" href="'+c.url+'" aria-label="Explore '+c.name+' in detail" style="--metal:'+c.finish+';--card-ink:'+c.ink+'"><div class="card-turn"><div class="face" aria-hidden="true"><span class="card-brand">shuffl</span><span class="chip"></span><span class="card-name">'+c.name+'</span></div><div class="face back" aria-hidden="true"><span>Explore this card more</span></div></div></a><details class="why"><summary>Why this card?</summary><p>'+c.use+'</p><p data-why="'+i+'"></p></details></div><div><span class="role">'+c.role+'</span><h2>'+c.name+'</h2><ul class="perks">'+c.perks.map(p=>'<li>'+p+'</li>').join('')+'</ul><div class="card-bottom"><div class="reward"><span data-reward="'+i+'"></span> <small>/ year</small></div><div class="actions"><button class="keep" data-keep="'+i+'" aria-pressed="'+kept[i]+'" aria-label="'+(kept[i]?'Unkeep ':'Keep ')+c.name+'">'+(kept[i]?'Kept':'Keep')+'</button><button data-swap="'+i+'" aria-label="Swap '+c.name+'" '+(kept[i]||catalog.length===selected.length?'disabled':'')+'>Swap</button></div></div></div></article>'}).join('');update();}
function update(){amounts.forEach((amount,i)=>{const input=root.querySelector('#category-'+i);input.value=amount;input.setAttribute('aria-valuetext',money(amount)+' per month');paintRange(input);root.querySelector('#category-value-'+i).textContent=money(amount);});selected.forEach((id,i)=>{const why=root.querySelector('[data-why="'+i+'"]');if(why)why.textContent=allocation(catalog[id])?money(allocation(catalog[id]))+' of your monthly spending is assigned to this card, earning an estimated '+cents(reward(catalog[id]))+' a year before fees.':'Other cards in this stack match or beat this card’s rates for your current spending. Its perks may still be useful; swap it to compare alternatives.';});persist();syncSave();const cards=selected.map(id=>catalog[id]),gross=cards.reduce((s,c)=>s+reward(c),0),fees=cards.reduce((s,c)=>s+c.fee,0);root.querySelector('#total').innerHTML=cents(gross-fees).replace(/([.][0-9]{2})$/, '<small>$1</small>');root.querySelector('#gross').textContent=cents(gross);root.querySelector('#fees').textContent=fees?'−'+money(fees):money(0);root.querySelector('#spend-value').textContent=money(spend.value);spend.setAttribute('aria-valuetext',money(spend.value)+' per month');spend.style.background='linear-gradient(to right,var(--wine) '+spend.value/100+'%,#e8e8e8 '+spend.value/100+'%)';cards.forEach((c,i)=>root.querySelector('[data-reward="'+i+'"]').textContent=cents(reward(c)));root.querySelector('#kept-count').textContent=selected.length+' cards · '+kept.filter(Boolean).length+' kept';root.querySelector('#timeline').innerHTML=cards.map((c,i)=>'<li><span class="step">'+(i+1)+'</span><span class="when">'+(i===0?'Start here':'Then, around month '+(i*3+1))+'</span><strong>'+c.name+'</strong></li>').join('');}
spend.addEventListener('input',()=>{
  const total=Number(spend.value),previous=amounts.reduce((a,b)=>a+b,0),ratios=previous?amounts.map(n=>n/previous):data.amounts.map(n=>n/data.amounts.reduce((a,b)=>a+b,0));
  let remaining=total;
  amounts.forEach((_,i)=>{amounts[i]=i===amounts.length-1?remaining:Math.min(remaining,Math.round(total*ratios[i]));remaining-=amounts[i];});update();
});
root.querySelector('#cards').addEventListener('click',e=>{const b=e.target.closest('button');if(!b)return;if(b.hasAttribute('data-keep')){const i=Number(b.dataset.keep);kept[i]=!kept[i];renderCards();root.querySelector('[data-keep="'+i+'"]').focus();root.querySelector('#status').textContent=kept[i]?catalog[selected[i]].name+' kept. Unkeep it if you want to swap.':catalog[selected[i]].name+' can now be swapped.';}else{const i=Number(b.dataset.swap);const next=catalog.map((_,id)=>id).find(id=>id>selected[i]&&!selected.includes(id))??catalog.map((_,id)=>id).find(id=>!selected.includes(id));if(next===undefined)return;selected[i]=next;renderCards();root.querySelector('[data-swap="'+i+'"]').focus();root.querySelector('#status').textContent='Swapped to '+catalog[selected[i]].name+'. Your value and timeline are updated.';}});
renderCards();
  }
}
