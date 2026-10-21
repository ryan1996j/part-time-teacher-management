/* Click-through UI preview. Input values are never read or validated. */
$(function(){
  let role='admin';
  $('[data-demo]').on('click',function(){role=$(this).data('demo')==='teacher'?'teacher':'admin';$('#credential-hint').text('Selected demo role: '+(role==='admin'?'Admin':'Teacher'));});
  $('#captcha-image').text('DEMO');
  $('#show-password').on('click',function(){const show=$('#password').attr('type')==='password';$('#password').attr('type',show?'text':'password');$(this).text(show?'Hide':'Show');});
  $('#login-form').on('submit',function(ev){
    ev.preventDefault();
    try{sessionStorage.setItem('ai14-demo-session',JSON.stringify({role:role,teacherId:role==='teacher'?'T001':null,name:role==='admin'?'School Admin':'Aye Aye Win',verified:true,at:new Date().toISOString()}));}
    catch{$('#login-error').text('Allow session storage to explore the demo.').removeClass('hidden');return;}
    $('#password,#email,#captcha-input').val('');
    location.replace('index.html#'+(role==='admin'?'overview':'home'));
  });
  $('#forgot').on('click',function(){$('#login-view').addClass('hidden');$('#recovery-view').removeClass('hidden');});
  $('[data-back]').on('click',function(){$('#recovery-view,#otp-view').addClass('hidden');$('#login-view').removeClass('hidden');});
});
