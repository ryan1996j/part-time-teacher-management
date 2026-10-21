/* Fictional demo role selection. No credentials are requested or processed. */
$(function(){
  const roles={admin:{name:'School Admin',teacherId:null,page:'overview'},teacher:{name:'Aye Aye Win',teacherId:'T001',page:'home'}};
  $('[data-demo]').on('click',function(){
    const role=$(this).data('demo'),choice=roles[role];if(!choice)return;
    try{sessionStorage.setItem('ai14-demo-session',JSON.stringify({role:role,teacherId:choice.teacherId,name:choice.name,verified:true,at:new Date().toISOString()}));}
    catch{$('#entry-error').text('Allow browser session storage to explore this demo.');return;}
    location.replace('index.html#'+choice.page);
  });
});
