/* View-model helpers shared by the UI and flow regression tests. */
(function(root,factory){if(typeof module==='object'&&module.exports)module.exports=factory();else root.FlowUI=factory();})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';
  const date=value=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Yangon',year:'numeric',month:'2-digit',day:'2-digit'}).format(value?new Date(value):new Date());
  function route(hash,role){
    const [raw,search='']=String(hash||'').replace(/^#/,'').split('?'),params=new URLSearchParams(search);
    const allowed=role==='admin'?['overview','teachers','classes','sessions','reviews','payroll','payments','audit']:['home','sessions','reviews','payments'];
    const page=allowed.includes(raw)?raw:role==='admin'?'overview':'home';
    return {page,sessionFilter:['Pending','Verified','Rejected','Missing checkout','In progress'].includes(params.get('status'))?params.get('status'):'',reviewView:params.get('view')==='sessions'?'sessions':'corrections',reviewTab:['Pending','Approved','Rejected','Withdrawn','All'].includes(params.get('tab'))?params.get('tab'):'Pending',paymentFilter:['unpaid','paid'].includes(params.get('status'))?params.get('status'):'all',paymentRun:params.get('run')||''};
  }
  function href(page,params={}){const q=new URLSearchParams(Object.entries(params).filter(([,v])=>v!==''&&v!==null&&v!==undefined));return '#'+page+(q.size?'?'+q:'');}
  const pendingRequest=(store,s)=>store.data.corrections.find(c=>c.session===s.id&&c.status==='Pending');
  const status=(s,today=date())=>!s.end?(date(s.start)===today?'In progress':'Missing checkout'):s.status;
  const verificationQueue=store=>store.data.sessions.filter(s=>s.end&&s.status==='Pending'&&!store.pending(s)&&!store.locked(s));
  const currentRate=(teacher,today=date())=>[...teacher.rates].filter(r=>r.from<=today).sort((a,b)=>b.from.localeCompare(a.from))[0]||null;
  const assignedClasses=(store,id)=>{const t=store.data.teachers.find(t=>t.id===id);return t?store.data.classes.filter(c=>c.active&&t.assignments.includes(c.id)):[];};
  function paymentRows(store,role,teacherId){return store.data.runs.filter(r=>r.status==='Approved').flatMap(run=>[...new Set(run.lines.map(l=>l.teacher))].filter(id=>role==='admin'||id===teacherId).map(id=>({run,id,payment:store.data.payments.find(p=>p.run===run.id&&p.teacher===id&&p.status==='Paid')})));}
  function activity(sessions){
    const end=sessions.length?sessions.map(s=>date(s.start)).sort().at(-1):date(),dates=[];
    for(let n=6;n>=0;n--){const d=new Date(end+'T12:00:00Z');d.setUTCDate(d.getUTCDate()-n);dates.push(d.toISOString().slice(0,10));}
    const hours=dates.map(d=>sessions.filter(s=>s.end&&date(s.start)===d).reduce((n,s)=>n+Math.max(0,Math.floor((new Date(s.end)-new Date(s.start))/60000))/60,0));
    return {dates,hours,from:dates[0],to:dates.at(-1)};
  }
  function period(sessions){const last=sessions.length?sessions.map(s=>date(s.start)).sort().at(-1):date(),start=new Date(last+'T12:00:00Z');start.setUTCDate(start.getUTCDate()-((start.getUTCDay()+6)%7));const end=new Date(start);end.setUTCDate(end.getUTCDate()+6);return {from:start.toISOString().slice(0,10),to:end.toISOString().slice(0,10)};}
  return {period,date,route,href,pendingRequest,status,verificationQueue,currentRate,assignedClasses,paymentRows,activity};
});
