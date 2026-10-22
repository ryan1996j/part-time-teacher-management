/* Browser-only demo state. No API, database, authentication or real payments. */
(function(root,factory){if(typeof module==='object'&&module.exports)module.exports=factory();else root.EduDemo=factory();})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';
  const clone=x=>JSON.parse(JSON.stringify(x));
  const stamp=(day,time)=>`2026-10-${String(day).padStart(2,'0')}T${time}:00+06:30`;
  const mins=(a,b)=>a&&b?Math.floor((new Date(b)-new Date(a))/60000):0;
  const money=(minutes,rate)=>Math.floor((minutes*rate+30)/60);
  function seed(){
    const teachers=[['T001','Aye Aye Win','aye.aye@example.com',10000,['C101','C102']],['T002','Ko Min Thu','min.thu@example.com',12000,['C103','C101']],['T003','Su Su Hlaing','susu@example.com',11000,['C102','C103','C101']],['T004','Nandar Oo','nandar@example.com',10000,['C101','C102','C103']],['T005','Htet Htet Aung','htet@example.com',13000,['C103','C101','C102']]].map((t,i)=>({id:t[0],name:t[1],email:t[2],rates:[{from:'2026-10-01',rate:t[3]}],assignments:t[4],active:true,tone:i}));
    const classes=[{id:'C101',name:'Mathematics Class',subject:'Mathematics',active:true},{id:'C102',name:'English Class',subject:'English',active:true},{id:'C103',name:'Science Class',subject:'Science',active:true}];
    const raw=[['T001','C101',12,'09:00','10:00'],['T001','C102',12,'10:30','12:00'],['T002','C101',12,'13:00','14:00'],['T003','C102',13,'09:15','11:15'],['T004','C103',13,'14:00','15:30'],['T005','C101',14,'08:30','09:30'],['T001','C101',14,'09:00','10:00'],['T002','C103',15,'13:30',null],['T003','C101',15,'10:00','11:00'],['T004','C102',16,'15:00','16:30'],['T005','C102',16,'09:00','11:00'],['T002','C101',17,'08:45','09:45']];
    const sessions=raw.map((r,i)=>({id:'S'+String(i+1).padStart(4,'0'),teacher:r[0],classId:r[1],start:stamp(r[2],r[3]),end:r[4]?stamp(r[2],r[4]):null,originalStart:stamp(r[2],r[3]),originalEnd:r[4]?stamp(r[2],r[4]):null,status:[0,1,4,7].includes(i)?'Pending':'Verified',source:'Teacher check-in',version:1,note:i===4?'Checkout time may be incorrect':i===7?'Forgot to check out':'',flag:''}));
    sessions[2].start=stamp(12,'12:55');
    const corrections=[{id:'CR001',session:'S0005',start:stamp(13,'14:00'),end:stamp(13,'15:45'),reason:'Class ended 15 minutes later than recorded.',status:'Pending',comment:'',baseVersion:1},{id:'CR002',session:'S0008',start:stamp(15,'13:30'),end:stamp(15,'15:00'),reason:'I forgot to check out after class.',status:'Pending',comment:'',baseVersion:1},{id:'CR003',session:'S0003',start:stamp(12,'12:55'),end:stamp(12,'14:00'),reason:'Arrived five minutes before the scheduled start.',status:'Approved',comment:'Approved based on class log.',baseVersion:1},{id:'CR004',session:'S0006',start:stamp(14,'08:30'),end:stamp(14,'10:00'),reason:'Please check if the class ran until 10:00.',status:'Rejected',comment:'Attendance confirms 09:30 checkout.',baseVersion:1}];
    return {schema:1,teachers,classes,sessions,corrections,runs:[],payments:[],audit:[{id:'EV001',at:'2026-10-19T09:00:00+06:30',actor:'Admin',action:'Demo workspace prepared',detail:'Fictional sample records · 12–17 October 2026'}]};
  }
  class Store {
    constructor(data){this.data=data?clone(data):seed();}
    teacher(id){const t=this.data.teachers.find(t=>t.id===id);if(!t)throw Error('Teacher not found.');return t;}
    session(id){const s=this.data.sessions.find(s=>s.id===id);if(!s)throw Error('Session not found.');return s;}
    log(action,detail,actor='Admin'){this.data.audit.unshift({id:this.id('EV'),at:new Date().toISOString(),actor,action,detail});}
    id(prefix){return prefix+Date.now().toString(36)+Math.random().toString(36).slice(2,6);}
    rate(s){const date=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Yangon',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(s.start));return [...this.teacher(s.teacher).rates].sort((a,b)=>b.from.localeCompare(a.from)).find(r=>r.from<=date)?.rate??null;}
    pending(s){return this.data.corrections.some(c=>c.session===s.id&&c.status==='Pending');}
    locked(s){return this.data.runs.some(r=>r.status==='Approved'&&r.lines.some(l=>l.session===s.id));}
    reason(s){if(!s.end)return 'Missing checkout';if(mins(s.start,s.end)<=0)return 'Invalid duration';if(this.pending(s))return 'Pending correction';if(s.flag)return s.flag;if(s.status!=='Verified')return s.status==='Rejected'?'Rejected session':'Awaiting verification';if(this.rate(s)===null)return 'Missing hourly rate';if(this.locked(s))return 'Already in approved payroll';return '';}
    checkInBlocker(teacher,now=new Date().toISOString()){
      return this.data.sessions.filter(s=>s.teacher===teacher&&!s.end).sort((a,b)=>new Date(b.start)-new Date(a.start)).find(s=>{
        const c=this.data.corrections.find(c=>c.session===s.id&&c.status==='Pending');
        return !(c&&Number.isFinite(Date.parse(c.start))&&Number.isFinite(Date.parse(c.end))&&new Date(c.end)>new Date(c.start)&&new Date(c.end)<=new Date(now));
      })||null;
    }
    overlaps(s,start,end){return this.data.sessions.some(other=>{
      if(other.id===s.id||other.teacher!==s.teacher)return false;
      const c=this.data.corrections.find(c=>c.session===other.id&&c.status==='Pending'),from=c?.start||other.start,to=c?.end||other.end;
      return new Date(start)<(to?new Date(to):Infinity)&&new Date(end)>new Date(from);
    });}
    checkIn(teacher,classId,now=new Date().toISOString()){
      const t=this.teacher(teacher);if(!t.active)throw Error('This teacher account is inactive.');
      if(!t.assignments.includes(classId)||!this.data.classes.some(c=>c.id===classId&&c.active))throw Error('Choose an active assigned class.');
      if(this.checkInBlocker(teacher,now))throw Error('You have an open session. Check out or submit its actual end time as a correction first.');
      if(this.overlaps({id:null,teacher},now,new Date(new Date(now).getTime()+1).toISOString()))throw Error('Check-in overlaps a recorded or requested class time. Review your class records first.');
      const s={id:this.id('S'),teacher,classId,start:now,end:null,originalStart:now,originalEnd:null,status:'Pending',source:'Teacher check-in',version:1,note:'',flag:''};
      this.data.sessions.push(s);this.log('Checked in',s.id+' · '+classId,t.name);return s;
    }
    checkOut(id,now=new Date().toISOString()){
      const s=this.session(id);if(s.end)return s;if(new Date(now)<=new Date(s.start))throw Error('Checkout must be after check-in.');
      s.end=now;s.originalEnd=now;s.version++;if(mins(s.start,s.end)>360)s.flag='Long duration — review required';this.log('Checked out',s.id,this.teacher(s.teacher).name);return s;
    }
    addSession(teacher,classId,start,end,reason){
      const t=this.teacher(teacher);if(!t.active)throw Error('Teacher is inactive.');
      if(!t.assignments.includes(classId))throw Error('Assign this class to the teacher first.');
      if(!reason.trim())throw Error('An admin entry reason is required.');
      if(!start||!end||mins(start,end)<=0)throw Error('Enter a valid start and end date/time.');
      if(this.data.sessions.some(s=>s.teacher===teacher&&s.start===start&&s.end===end))throw Error('This session already exists.');
      if(this.data.sessions.some(s=>s.teacher===teacher&&s.end&&new Date(start)<new Date(s.end)&&new Date(end)>new Date(s.start)))throw Error('This overlaps another teaching session.');
      const s={id:this.id('S'),teacher,classId,start,end,originalStart:start,originalEnd:end,status:'Pending',source:'Admin entry',version:1,note:reason,flag:mins(start,end)>360?'Long duration — review required':''};
      this.data.sessions.push(s);this.log('Admin session recorded',s.id+' · '+reason);return s;
    }
    request(id,start,end,reason){
      const s=this.session(id);if(this.locked(s))throw Error('This session is locked in approved payroll. Contact Admin for an adjustment.');
      if(this.pending(s))throw Error('There is already a pending correction.');
      if(!reason.trim())throw Error('Please explain the correction.');if(!start||!end||mins(start,end)<=0)throw Error('End date/time must be after start date/time.');
      if(this.overlaps(s,start,end))throw Error('The corrected times overlap another class. Check the start and end times.');
      const c={id:this.id('CR'),session:id,start,end,reason,status:'Pending',comment:'',baseVersion:s.version};this.data.corrections.push(c);this.log('Correction requested',id+' · '+reason,this.teacher(s.teacher).name);return c;
    }
    review(id,decision,comment){
      const c=this.data.corrections.find(c=>c.id===id);if(!c||c.status!=='Pending')throw Error('This request has already been reviewed.');
      const s=this.session(c.session);if(this.locked(s))throw Error('Session is locked in approved payroll.');
      if(c.baseVersion!==s.version)throw Error('Session changed. Refresh and review the latest version.');
      if(decision==='Rejected'&&!comment.trim())throw Error('A rejection reason is required.');
      if(decision==='Approved'&&this.overlaps(s,c.start,c.end))throw Error('The corrected times overlap another class. Reject this request so the teacher can submit corrected times.');
      c.status=decision;c.comment=comment;
      if(decision==='Approved'){s.start=c.start;s.end=c.end;s.status='Pending';s.version++;s.flag=mins(s.start,s.end)>360?'Long duration — review required':'';}
      this.log('Correction '+decision.toLowerCase(),c.session+' · '+(comment||c.reason));
    }
    verify(id,decision,reason=''){
      const s=this.session(id);if(this.locked(s))throw Error('Session is locked.');if(!s.end)throw Error('Resolve the missing checkout first.');if(this.pending(s))throw Error('Review the pending correction first.');
      if(decision==='Rejected'&&!reason.trim())throw Error('A rejection reason is required.');if(s.flag&&!reason.trim())throw Error('Explain how the exception was resolved.');
      s.status=decision;s.flag='';s.version++;s.reviewNote=reason;this.log('Session '+decision.toLowerCase(),id+(reason?' · '+reason:''));
    }
    withdraw(id){const c=this.data.corrections.find(c=>c.id===id);if(!c||c.status!=='Pending')throw Error('Only pending requests can be withdrawn.');c.status='Withdrawn';this.log('Correction withdrawn',c.session,this.teacher(this.session(c.session).teacher).name);}
    fingerprint(){return JSON.stringify({sessions:this.data.sessions,corrections:this.data.corrections,teachers:this.data.teachers,runs:this.data.runs.filter(r=>r.status==='Approved')});}
    draft(from,to){
      if(!from||!to||from>to)throw Error('Choose a valid payroll period.');
      const within=this.data.sessions.filter(s=>{const d=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Yangon',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(s.start));return d>=from&&d<=to;});
      const held=[],lines=[];
      within.forEach(s=>{const reason=this.reason(s);if(reason)held.push({session:s.id,teacher:s.teacher,reason});else {const minutes=mins(s.start,s.end),rate=this.rate(s);lines.push({session:s.id,teacher:s.teacher,classId:s.classId,start:s.start,end:s.end,minutes,rate,amount:money(minutes,rate),version:s.version});}});
      return {id:this.id('PAY'),from,to,status:'Draft',lines,held,adjustments:{},fingerprint:this.fingerprint()};
    }
    total(run,teacher){const lines=run.lines.filter(l=>!teacher||l.teacher===teacher);const adjustments=Object.entries(run.adjustments||{}).filter(([id])=>!teacher||id===teacher).reduce((n,[,a])=>n+a.amount,0);return {minutes:lines.reduce((n,l)=>n+l.minutes,0),gross:lines.reduce((n,l)=>n+l.amount,0),adjustments,net:lines.reduce((n,l)=>n+l.amount,0)+adjustments};}
    approve(run){
      if(!run||run.status!=='Draft'||!run.lines.length)throw Error('Calculate a payroll with eligible sessions first.');if(run.fingerprint!==this.fingerprint())throw Error('Records changed since calculation. Recalculate the draft.');
      for(const t of new Set(run.lines.map(l=>l.teacher)))if(this.total(run,t).net<0)throw Error('Teacher net pay cannot be negative.');
      const frozen=clone(run);delete frozen.fingerprint;frozen.status='Approved';frozen.approvedAt=new Date().toISOString();frozen.policy='Minutes × hourly rate; session round-half-up MMK';this.data.runs.unshift(frozen);this.log('Payroll approved',run.from+' → '+run.to+' · '+this.total(run).net+' MMK');return frozen;
    }
    pay(runId,teacher,method,date,reference){
      const run=this.data.runs.find(r=>r.id===runId);if(!run||run.status!=='Approved')throw Error('Only approved payroll can be marked paid.');if(!run.lines.some(l=>l.teacher===teacher))throw Error('Teacher is not in this payroll.');
      if(this.data.payments.some(p=>p.run===runId&&p.teacher===teacher&&p.status==='Paid'))throw Error('This teacher is already paid for this payroll.');if(!date||!reference.trim())throw Error('Payment date and reference or receipt note are required.');
      const p={id:this.id('PMT'),run:runId,teacher,amount:this.total(run,teacher).net,method,date,reference,status:'Paid'};this.data.payments.unshift(p);this.log('Payment recorded',this.teacher(teacher).name+' · '+p.amount+' MMK · '+reference);return p;
    }
    voidRun(id,reason){const run=this.data.runs.find(r=>r.id===id);if(!run||run.status!=='Approved')throw Error('Choose an approved payroll.');if(this.data.payments.some(p=>p.run===id&&p.status==='Paid'))throw Error('This payroll has paid teachers. Use a future adjustment instead.');if(!reason.trim())throw Error('A void reason is required.');run.status='Void';run.voidReason=reason;this.log('Payroll voided',id+' · '+reason);}
    reversePayment(id,reason){const p=this.data.payments.find(p=>p.id===id);if(!p||p.status!=='Paid')throw Error('Choose a paid record.');if(!reason.trim())throw Error('A reversal reason is required.');p.status='Reversed';p.reversalReason=reason;this.log('Payment record reversed',p.reference+' · '+reason);}
  }
  return {Store,seed,mins,money,clone};
});
