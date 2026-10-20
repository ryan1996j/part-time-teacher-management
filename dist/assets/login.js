/* UI simulation only. No real credentials, authentication, CAPTCHA provider or 2FA delivery. */
$(function(){
  const accounts={admin:{email:'admin@ai14.demo',password:'Admin123!',name:'School Admin',role:'Admin',destination:'Admin Overview'},teacher:{email:'teacher@ai14.demo',password:'Teacher123!',name:'Aye Aye Win',role:'Teacher',destination:'My Workspace'}};
  let challenge='',pendingAccount=null,otp='',expiresAt=0,interval=null;
  function accountActive(a){if(a.role!=='Teacher')return true;try{const data=JSON.parse(localStorage.getItem('ai14-educontrol-ui-v03'));return data?.teachers?.find(t=>t.id==='T001')?.active!==false;}catch{return true;}}
  function refreshCaptcha(){const chars='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';challenge=Array.from({length:5},()=>chars[Math.floor(Math.random()*chars.length)]).join('');$('#captcha-image').text(challenge);$('#captcha-input').val('').attr('aria-invalid','false');$('#captcha-error').text('');}
  function clearErrors(){$('#email-error,#password-error,#captcha-error,#login-error,#otp-error').text('');$('#login-error').addClass('hidden');$('#email,#password,#captcha-input,#otp-input').attr('aria-invalid','false');}
  function tick(){const left=Math.max(0,Math.ceil((expiresAt-Date.now())/1000));$('#otp-timer').text(left?'Code valid for '+String(Math.floor(left/60)).padStart(2,'0')+':'+String(left%60).padStart(2,'0'):'Code expired · request a new demo code');if(!left){clearInterval(interval);interval=null;}}
  function issueCode(){otp=String(Math.floor(100000+Math.random()*900000));expiresAt=Date.now()+120000;$('#demo-otp-code').text(otp);$('#otp-input').val('').attr('aria-invalid','false');$('#otp-error').text('');clearInterval(interval);tick();interval=setInterval(tick,1000);}
  $('[data-demo]').on('click',function(){const a=accounts[$(this).data('demo')];clearErrors();$('#email').val(a.email);$('#password').val(a.password);$('#credential-hint').text('Email: '+a.email+' · Password: '+a.password);$('#captcha-input').trigger('focus');});
  $('#refresh-captcha').on('click',function(){refreshCaptcha();$('#captcha-input').trigger('focus');});
  $('#show-password').on('click',function(){const show=$('#password').attr('type')==='password';$('#password').attr('type',show?'text':'password');$(this).text(show?'Hide':'Show').attr('aria-label',show?'Hide password':'Show password');});
  $('#login-form').on('submit',function(ev){ev.preventDefault();clearErrors();pendingAccount=null;const email=$('#email').val().trim().toLowerCase(),password=$('#password').val(),answer=$('#captcha-input').val().trim().toUpperCase();let first=null;
    if(!email||!/^\S+@\S+\.\S+$/.test(email)){$('#email-error').text('မှန်ကန်တဲ့ email address ထည့်ပါ။');$('#email').attr('aria-invalid','true');first='#email';}
    if(!password){$('#password-error').text('Password ထည့်ပါ။');$('#password').attr('aria-invalid','true');first=first||'#password';}
    if(answer!==challenge){$('#captcha-error').text('Security characters မမှန်ပါ။ ပြန်စစ်ပြီးထည့်ပါ။');$('#captcha-input').attr('aria-invalid','true');first=first||'#captcha-input';}
    if(first){$(first).trigger('focus');return;}
    const account=Object.values(accounts).find(a=>a.email===email&&a.password===password);if(!account){$('#login-error').text('Email or password is incorrect. Demo account ကိုရွေးပြီး ပြန်စမ်းပါ။').removeClass('hidden');$('#password').val('').attr('aria-invalid','true').trigger('focus');refreshCaptcha();return;}
    if(!accountActive(account)){$('#login-error').text('This demo teacher account is inactive. Contact Admin.').removeClass('hidden');return;}
    pendingAccount=account;$('#password').val('');$('#login-view').addClass('hidden');$('#otp-view').removeClass('hidden');$('#otp-destination').text('Demo email: '+account.email.replace(/^(.{2}).*(@.*)$/,'$1••••$2')+' · '+account.role+' account');issueCode();$('#otp-input').trigger('focus');
  });
  $('#otp-input').on('input',function(){this.value=this.value.replace(/\D/g,'').slice(0,6);});
  $('#fill-otp').on('click',function(){$('#otp-input').val(otp).trigger('focus');});
  $('#resend-code').on('click',function(){if(!pendingAccount)return;issueCode();$('#otp-error').text('New demo code generated. No email or SMS was sent.');$('#otp-input').trigger('focus');});
  $('#otp-form').on('submit',function(ev){ev.preventDefault();$('#otp-error').text('');if(!pendingAccount)return;if(Date.now()>=expiresAt){$('#otp-error').text('Code သက်တမ်းကုန်ပါပြီ။ Resend demo code နှိပ်ပါ။');$('#otp-input').attr('aria-invalid','true');return;}if($('#otp-input').val()!==otp){$('#otp-error').text('Code မမှန်ပါ။ ဂဏန်း ၆ လုံးကို ပြန်စစ်ပါ။');$('#otp-input').attr('aria-invalid','true').trigger('focus');return;}
    const a=pendingAccount;
    if(!accountActive(a)){$('#otp-error').text('This demo account is inactive. Contact Admin.');return;}
    clearInterval(interval);interval=null;pendingAccount=null;otp='';$('#otp-input').val('');
    try{sessionStorage.setItem('ai14-demo-session',JSON.stringify({role:a.role.toLowerCase(),teacherId:a.role==='Teacher'?'T001':null,name:a.name,verified:true,at:new Date().toISOString()}));}
    catch{$('#otp-error').text('Enable browser session storage to enter this UI prototype.');return;}
    window.location.replace('index.html#'+(a.role==='Admin'?'overview':'home'));

  });
  $('#forgot').on('click',function(){$('#login-view').addClass('hidden');$('#recovery-view').removeClass('hidden');});
  $(document).on('click','[data-back]',function(){clearInterval(interval);interval=null;pendingAccount=null;otp='';expiresAt=0;$('#success-view,#recovery-view,#otp-view').addClass('hidden');$('#login-view').removeClass('hidden');clearErrors();refreshCaptcha();$('#password,#otp-input').val('');$('#password').attr('type','password');$('#show-password').text('Show').attr('aria-label','Show password');$('#email').trigger('focus');});
  refreshCaptcha();
});
