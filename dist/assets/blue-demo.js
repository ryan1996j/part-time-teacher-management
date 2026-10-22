/* Local design review enhancements only; no server, analytics or production changes. */
(function($){
  'use strict';let seq=0;
  function identify(field){if(!field.id)field.id='blue-field-'+(++seq);return field.id;}
  function inlineError(field,message){const id=identify(field),errorId=id+'-error';let error=document.getElementById(errorId);if(!error){error=document.createElement('small');error.id=errorId;error.className='field-error';error.setAttribute('aria-live','polite');field.closest('label')?.appendChild(error);}if(error)error.textContent=message;field.setAttribute('aria-invalid',message?'true':'false');const described=new Set((field.getAttribute('aria-describedby')||'').split(' ').filter(Boolean));described.add(errorId);field.setAttribute('aria-describedby',[...described].join(' '));}
  window.decorateBlueUI=function(scope){
    $(scope).find('.field').each(function(){const field=$(this).find('input,select,textarea').first()[0];if(!field)return;identify(field);this.setAttribute('for',field.id);const title=$(this).children('span').first().text();field.setAttribute('aria-label',title);if(field.name==='rate'){field.min='1';field.step='1';}if(field.name==='amount')field.step='1';});
    $(scope).find('th:not([scope])').attr('scope','col');
    $(scope).find('.nav-link.active').attr('aria-current','page');
    $(scope).find('.bar[title]').each(function(){this.setAttribute('role','img');this.setAttribute('aria-label',this.title);});
  };
  document.addEventListener('invalid',function(ev){const field=ev.target;if(!field.closest('#modal'))return;ev.preventDefault();const label=field.getAttribute('aria-label')||field.name||'This field';inlineError(field,field.validity.valueMissing?label+' is required.':field.validationMessage);if(!document.querySelector('#modal [aria-invalid="true"]:focus'))setTimeout(()=>document.querySelector('#modal [aria-invalid="true"]')?.focus(),0);},true);
  $(document).on('input.blueValidation change.blueValidation','#modal input,#modal textarea,#modal select',function(){if(this.getAttribute('aria-invalid')==='true'&&this.validity.valid)inlineError(this,'');});
  $(document).on('keydown.blueShortcut',function(ev){if(ev.altKey&&ev.key==='/'&&!/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)&&document.getElementById('session-search')){ev.preventDefault();$('#session-search').trigger('focus');}});
  $(function(){window.decorateBlueUI(document);});
})(jQuery);
