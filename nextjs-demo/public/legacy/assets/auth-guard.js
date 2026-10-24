/* UI routing only. Browser sessionStorage is not real access control. */
(function(){
  function guard(){
    let session=null;
    try{session=JSON.parse(sessionStorage.getItem('ai14-blue-demo-session'));}catch{}
    if(!session?.verified||!['admin','teacher'].includes(session.role)){
      document.documentElement.style.visibility='hidden';
      location.replace('login.html');
    }
  }
  guard();
  window.addEventListener('pageshow',guard);
})();
