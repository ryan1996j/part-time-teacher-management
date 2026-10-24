/* Mobile navigation uses a contained, dismissible drawer. */
(function(){
  'use strict';
  const sidebar=document.getElementById('sidebar'),toggle=document.getElementById('menu-toggle'),close=document.getElementById('sidebar-close'),scrim=document.getElementById('nav-scrim'),main=document.querySelector('.main-shell');
  if(!sidebar||!toggle)return;
  const narrow=window.matchMedia('(max-width:900px)');let wasOpen=false;
  window.syncSidebarAccessibility=function(){
    const open=narrow.matches&&sidebar.classList.contains('open'),hidden=narrow.matches&&!open;
    sidebar.inert=hidden;sidebar.setAttribute('aria-hidden',String(hidden));toggle.setAttribute('aria-expanded',String(open));
    if(main)main.inert=open;if(scrim)scrim.hidden=!open;
    if(open){sidebar.setAttribute('role','dialog');sidebar.setAttribute('aria-modal','true');sidebar.setAttribute('aria-label','Navigation');if(!wasOpen)close?.focus();}
    else{sidebar.removeAttribute('role');sidebar.removeAttribute('aria-modal');sidebar.removeAttribute('aria-label');if(wasOpen)toggle.focus();}
    wasOpen=open;
  };
  function dismiss(){sidebar.classList.remove('open');window.syncSidebarAccessibility();}
  close?.addEventListener('click',dismiss);scrim?.addEventListener('click',dismiss);
  narrow.addEventListener('change',window.syncSidebarAccessibility);
  document.addEventListener('keydown',function(event){
    const modal=document.getElementById('modal');if(modal&&!modal.classList.contains('hidden'))return;
    if(!narrow.matches||!sidebar.classList.contains('open'))return;
    if(event.key==='Escape'){event.preventDefault();dismiss();return;}
    if(event.key==='Tab'){
      const items=[...sidebar.querySelectorAll('a[href],button:not(:disabled)')].filter(e=>e.offsetParent!==null),first=items[0],last=items.at(-1);
      if(event.shiftKey&&document.activeElement===first){event.preventDefault();last?.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first?.focus();}
    }
  });
  window.syncSidebarAccessibility();
})();
