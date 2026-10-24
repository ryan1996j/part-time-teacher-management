/* Shared date picker. Native date/time inputs retain validation and ISO values. */
(function($){
  'use strict';
  const calendarIcon='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 5h16v16H4z M8 3v4 M16 3v4 M4 10h16"/></svg>';
  const pad=n=>String(n).padStart(2,'0');
  const iso=d=>`${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`;
  const parse=value=>{const m=/^(\d{4})-(\d{2})-(\d{2})/.exec(value||'');return m?new Date(+m[1],+m[2]-1,+m[3],12):null;};
  let input=null,trigger=null,month=null,focusDate=null;
  const popup=document.createElement('div');popup.className='date-popover';popup.hidden=true;popup.id='date-popover';popup.setAttribute('role','dialog');popup.setAttribute('aria-modal','false');popup.setAttribute('aria-label','Choose a date');document.body.append(popup);
  function close(restore=false){if(!input)return;popup.hidden=true;trigger?.setAttribute('aria-expanded','false');const oldTrigger=trigger;input=null;trigger=null;if(restore)oldTrigger?.focus();}
  window.closeDatePicker=close;
  function position(){if(!trigger)return;const r=trigger.getBoundingClientRect(),w=popup.offsetWidth,h=popup.offsetHeight;popup.style.left=Math.max(12,Math.min(r.right-w,innerWidth-w-12))+'px';popup.style.top=Math.max(12,Math.min(r.bottom+8,innerHeight-h-12))+'px';}
  function allowed(date){const min=parse(input.min),max=parse(input.max);return (!min||date>=min)&&(!max||date<=max);}
  function render(focus=true){
    const today=iso(new Date()),selected=(input.value||'').slice(0,10),year=month.getFullYear(),m=month.getMonth(),count=new Date(year,m+1,0).getDate(),offset=new Date(year,m,1).getDay();
    const weekdays=['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    popup.innerHTML=`<div class="calendar-head"><button type="button" class="calendar-nav" data-month="-1" aria-label="Previous month">‹</button><span class="calendar-title" aria-live="polite">${month.toLocaleDateString('en-GB',{month:'long',year:'numeric'})}</span><button type="button" class="calendar-nav" data-month="1" aria-label="Next month">›</button></div><div class="calendar-week" aria-hidden="true">${weekdays.map(d=>`<abbr title="${d}">${d.slice(0,2)}</abbr>`).join('')}</div><div class="calendar-days">${'<span></span>'.repeat(offset)}${Array.from({length:count},(_,i)=>{
      const date=new Date(year,m,i+1,12),value=iso(date),active=value===iso(focusDate),disabled=!allowed(date);
      return `<button type="button" class="calendar-day ${value===today?'today':''}" data-date="${value}" tabindex="${active&&!disabled?'0':'-1'}" aria-label="${date.toLocaleDateString('en-GB',{weekday:'long',day:'numeric',month:'long',year:'numeric'})}" aria-pressed="${value===selected}" ${value===today?'aria-current="date"':''} ${disabled?'disabled':''}>${i+1}</button>`;
    }).join('')}</div><div class="calendar-footer"><button type="button" data-today ${allowed(new Date(new Date().setHours(12,0,0,0)))?'':'disabled'}>Today</button><button type="button" data-close>Close</button></div>`;
    position();if(focus)popup.querySelector('.calendar-day[tabindex="0"]')?.focus({preventScroll:true});
  }
  function select(value){
    const source=input;
    if(source.type==='datetime-local')source.value=value+'T'+(source.value.split('T')[1]||'09:00');
    else source.value=value;
    source.dispatchEvent(new Event('input',{bubbles:true}));source.dispatchEvent(new Event('change',{bubbles:true}));close(true);
  }
  function open(source,button){
    close();input=source;trigger=button;trigger.setAttribute('aria-expanded','true');
    focusDate=parse(source.value)||parse(source.min)||new Date();focusDate.setHours(12,0,0,0);month=new Date(focusDate.getFullYear(),focusDate.getMonth(),1,12);
    // Keep popover inside the parent dialog so modal keyboard focus remains contained.
    (source.closest('.modal-panel')||document.body).append(popup);popup.hidden=false;render();
  }
  window.enhanceDates=function(scope){
    $(scope).find('input[type="date"],input[type="datetime-local"]').each(function(){
      if(this.closest('.date-field-wrap'))return;
      const source=this,label=this.getAttribute('aria-label')||this.closest('label')?.querySelector('span')?.textContent||this.name||'date';
      const wrap=document.createElement('span');wrap.className='date-field-wrap';source.before(wrap);wrap.append(source);
      const button=document.createElement('button');button.type='button';button.className='date-trigger';button.innerHTML=calendarIcon;button.setAttribute('aria-label','Choose '+label);button.setAttribute('aria-expanded','false');button.setAttribute('aria-haspopup','dialog');button.setAttribute('aria-controls',popup.id);wrap.append(button);
      button.addEventListener('click',()=>input===source?close(true):open(source,button));
      source.addEventListener('keydown',event=>{if(event.altKey&&event.key==='ArrowDown'){event.preventDefault();open(source,button);}});
    });
  };
  popup.addEventListener('click',event=>{
    const b=event.target.closest('button');if(!b||b.disabled)return;
    if(b.dataset.date)select(b.dataset.date);
    else if(b.dataset.month){const delta=+b.dataset.month,day=focusDate.getDate();month=new Date(month.getFullYear(),month.getMonth()+delta,1,12);focusDate=new Date(month.getFullYear(),month.getMonth(),Math.min(day,new Date(month.getFullYear(),month.getMonth()+1,0).getDate()),12);render(false);popup.querySelector(`[data-month="${delta}"]`).focus();}
    else if(b.hasAttribute('data-today'))select(iso(new Date()));
    else if(b.hasAttribute('data-close'))close(true);
  });
  popup.addEventListener('keydown',event=>{
    if(event.key==='Escape'){event.preventDefault();event.stopPropagation();close(true);return;}
    if(event.key==='Tab'){
      const controls=[...popup.querySelectorAll('button:not(:disabled)')].filter(b=>b.tabIndex>=0),first=controls[0],last=controls[controls.length-1];
      if(event.shiftKey&&event.target===first){event.preventDefault();last.focus();}else if(!event.shiftKey&&event.target===last){event.preventDefault();first.focus();}return;
    }
    if(!event.target.matches('.calendar-day'))return;
    const next=new Date(focusDate),keys={ArrowLeft:-1,ArrowRight:1,ArrowUp:-7,ArrowDown:7};
    if(event.key in keys)next.setDate(next.getDate()+keys[event.key]);
    else if(event.key==='Home')next.setDate(next.getDate()-next.getDay());
    else if(event.key==='End')next.setDate(next.getDate()+6-next.getDay());
    else if(['PageUp','PageDown'].includes(event.key)){const day=next.getDate();next.setDate(1);next.setMonth(next.getMonth()+(event.key==='PageUp'?-1:1));next.setDate(Math.min(day,new Date(next.getFullYear(),next.getMonth()+1,0).getDate()));}
    else return;
    event.preventDefault();if(!allowed(next))return;focusDate=next;month=new Date(next.getFullYear(),next.getMonth(),1,12);render();
  });
  document.addEventListener('pointerdown',event=>{if(input&&!popup.contains(event.target)&&!trigger?.contains(event.target))close();});
  document.addEventListener('focusin',event=>{if(input&&!popup.contains(event.target)&&event.target!==input&&event.target!==trigger)close();});
  window.addEventListener('resize',()=>close());window.addEventListener('scroll',event=>{if(event.target!==popup&&!popup.contains(event.target))close();},true);
})(jQuery);
