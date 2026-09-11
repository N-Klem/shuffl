import { Controller } from "@hotwired/stimulus"

// Preserve the original fan, blending into a vertical wheel within each column.
export default class extends Controller {
 connect() {

 const tile=this.element;
 const events=new AbortController();
 const listen=(element,type,handler,options={})=>element.addEventListener(type,handler,{...options,signal:events.signal});
 const fan=tile.querySelector('.stack-fan'),cards=[...fan.querySelectorAll('.fan-card')],button=tile.querySelector('button'),hint=tile.querySelector('.stack-hint');
 const originalHint=hint.innerHTML,reduce=matchMedia('(prefers-reduced-motion: reduce)');
 let expanded=false,pinned=false,phase=0,target=0,blend=0,raf=0,last=0,snapTimer,touchY=null,rest=[];
 fan.tabIndex=0;fan.setAttribute('role','region');
 function capture(){
  const was=tile.classList.contains('is-expanded');tile.classList.remove('is-expanded');
  rest=cards.map(c=>{const inline=c.style.transform;c.style.transform='';const m=new DOMMatrix(getComputedStyle(c).transform);c.style.transform=inline;return [m.a,m.b,m.c,m.d,m.e,m.f]});
  tile.classList.toggle('is-expanded',was);
 }
 function describe(){
  const index=((Math.round(phase)%cards.length)+cards.length)%cards.length;
  button.setAttribute('aria-expanded',expanded);
  if(expanded){hint.textContent=(index+1)+' / '+cards.length+' · Scroll to explore';fan.setAttribute('aria-label',cards[index].textContent.trim().replace(/\s+/g,' ')+'. '+(index+1)+' of '+cards.length)}
  else {hint.innerHTML=originalHint;fan.setAttribute('aria-label',button.getAttribute('aria-label'))}
  cards.forEach((c,i)=>{c.dataset.current=String(i===index);c.setAttribute('aria-hidden',!expanded);c.tabIndex=expanded?0:-1;c.setAttribute('aria-label',(i===index?'Current card: ':'Bring to front: ')+c.querySelector('.name').textContent)});
 }
 function draw(){
  cards.forEach((c,i)=>{
   const angle=(i-phase)*Math.PI/2,depth=(Math.cos(angle)+1)/2;
   const h=c.offsetHeight,top=parseFloat(getComputedStyle(c).top),radius=Math.max(20,(fan.clientHeight-h)/2+2);
   const scale=.76+.24*depth,scaleX=.64+.36*depth,y=fan.clientHeight/2-top-h/2+Math.sin(angle)*radius;
   const to=[scaleX,0,0,scale,0,y],matrix=rest[i].map((v,j)=>v+(to[j]-v)*blend);
   c.style.transform='matrix('+matrix.join(',')+')';
   c.style.opacity=String(1-blend*(1-depth)*.68);
   c.style.zIndex=blend>.4?String(Math.round(depth*100)+1):String(i+1);
  });describe();
 }
 function tick(now){
  const dt=last?Math.min((now-last)/1000,.05):.016;last=now;
  const destination=expanded?1:0;
  phase+=(target-phase)*(reduce.matches?1:1-Math.exp(-dt/.23));
  blend+=(destination-blend)*(reduce.matches?1:1-Math.exp(-dt/.22));
  draw();
  if(Math.abs(target-phase)>.0005||Math.abs(destination-blend)>.0005)raf=requestAnimationFrame(tick);
  else {phase=target;blend=destination;draw();raf=0;last=0;if(!expanded){tile.classList.remove('is-expanded');cards.forEach(c=>{c.style.transform='';c.style.opacity='';c.style.zIndex=''})}}
 }
 function wake(){if(!raf)raf=requestAnimationFrame(tick)}
 function open(value){expanded=value;if(value)tile.classList.add('is-expanded');wake()}
 function settle(){clearTimeout(snapTimer);snapTimer=setTimeout(()=>{target=Math.round(target);wake()},240)}
 listen(tile,'pointerenter',e=>{if(e.pointerType==='mouse')open(true)});
 listen(tile,'pointerleave',e=>{if(e.pointerType==='mouse'){target=Math.round(target);open(pinned)}});
 listen(button,'click',()=>{pinned=!pinned;open(pinned)});
 listen(fan,'click',e=>{if(e.target.closest('.fan-card'))return;pinned=!pinned;open(pinned)});
 cards.forEach((card,i)=>{
  card.setAttribute('role','button');
  function select(){
   clearTimeout(snapTimer);
   const current=((phase%cards.length)+cards.length)%cards.length;
   let distance=i-current;
   if(distance>cards.length/2)distance-=cards.length;
   if(distance<-cards.length/2)distance+=cards.length;
   target=phase+distance;pinned=true;open(true);
  }
  listen(card,'click',e=>{e.stopPropagation();select()});
  listen(card,'keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();e.stopPropagation();select()}});
 });
 listen(fan,'focus',()=>open(true));
 listen(tile,'focusout',e=>{if(!tile.contains(e.relatedTarget))open(pinned)});
 listen(fan,'wheel',e=>{
  if(e.ctrlKey||Math.abs(e.deltaX)>Math.abs(e.deltaY))return;
  e.preventDefault();open(true);
  const pixels=e.deltaY*(e.deltaMode===1?16:e.deltaMode===2?fan.clientHeight:1);
  target+=Math.max(-100,Math.min(100,pixels))/300;
  target=Math.max(phase-1.2,Math.min(phase+1.2,target));
  settle();wake();
 },{passive:false});
 listen(tile,'keydown',e=>{
  if(e.key==='Escape'){pinned=false;open(false);return}
  if(['ArrowDown','ArrowRight','ArrowUp','ArrowLeft'].includes(e.key)){e.preventDefault();clearTimeout(snapTimer);target=Math.round(target)+(e.key==='ArrowDown'||e.key==='ArrowRight'?1:-1);open(true)}
 });
 listen(fan,'pointerdown',e=>{if(e.pointerType==='touch'){touchY=e.clientY;open(true)}});
 listen(fan,'pointermove',e=>{if(e.pointerType==='touch'&&touchY!==null){target+=(touchY-e.clientY)/220;touchY=e.clientY;pinned=true;wake()}});
 listen(fan,'pointerup',()=>{touchY=null;settle()});
 listen(fan,'pointercancel',()=>{touchY=null;settle()});
 capture();describe();
 const observer=new ResizeObserver(()=>{capture();if(expanded)wake()});
 observer.observe(fan);
 this.cleanup=()=>{events.abort();observer.disconnect();cancelAnimationFrame(raf);clearTimeout(snapTimer);tile.classList.remove('is-expanded');hint.innerHTML=originalHint;cards.forEach(c=>{c.style.transform='';c.style.opacity='';c.style.zIndex=''})};

 }
 disconnect() { this.cleanup?.() }
}
