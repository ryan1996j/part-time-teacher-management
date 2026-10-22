/* Fictional UI role selection only. No credentials are collected. */
$(function(){
  'use strict';
  const roles={admin:{name:'School Admin',teacherId:null,page:'overview'},teacher:{name:'Aye Aye Win',teacherId:'T001',page:'home'}};
  $('[data-demo]').on('click',function(){
    const role=this.dataset.demo,account=roles[role];if(!account)return;
    try{
      sessionStorage.setItem('ai14-blue-demo-session',JSON.stringify({role,teacherId:account.teacherId,name:account.name,verified:true,at:new Date().toISOString()}));
    }catch{$('#entry-error').text('Browser session storage is unavailable. Enable it to explore the demo.');return;}
    location.replace('index.html#'+account.page);
  });
});
