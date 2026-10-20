/* Apply jQuery UI Selectmenu to current and dynamically rendered forms. */
(function($){
  'use strict';
  document.documentElement.dataset.inputMode='pointer';
  $(document).on('keydown.controlMode',function(e){if(['Tab','ArrowDown','ArrowUp','ArrowLeft','ArrowRight'].includes(e.key))document.documentElement.dataset.inputMode='keyboard';});
  $(document).on('pointerdown.controlMode',function(){document.documentElement.dataset.inputMode='pointer';});
  window.destroyControls=function(scope){$(scope).find('select').each(function(){if($(this).selectmenu('instance'))$(this).selectmenu('destroy');});};
  window.enhanceControls=function(scope){
    $(scope).find('select').each(function(){
      const select=$(this);if(select.prop('multiple'))return;
      if(select.selectmenu('instance')){select.selectmenu('refresh');return;}
      const label=select.attr('aria-label')||select.closest('label').children('span').first().text()||select.attr('name')||'Choose an option';
      const restoreLabel=function(){const instance=select.selectmenu('instance');if(instance)instance.widget().attr('aria-label',label).removeAttr('aria-labelledby');};
      select.selectmenu({width:select.closest('.field').length?'100%':false,appendTo:'body',open:restoreLabel,close:restoreLabel,focus:restoreLabel,select:restoreLabel,change:function(){restoreLabel();select.trigger('change');}});
      restoreLabel();
      select.selectmenu('widget').on('focus.controlLabel',restoreLabel);
      const menu=select.selectmenu('menuWidget');menu.attr('aria-label',label+' options');
    });
  };
  $(function(){window.enhanceControls(document);});
})(jQuery);
