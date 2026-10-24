const test=require('node:test');
const assert=require('node:assert/strict');
const {verifiedAccess}=require('../lib/verified-access.ts');
function fakeClient(role='teacher',teachers=[],failure=''){
 const tables={memberships:[{school_id:'school-a',user_id:'user-a',role,active:true}],teachers};
 return {from(table){let rows=tables[table]||[];const query={select(){return query;},eq(key,value){rows=rows.filter(row=>row[key]===value);return query;},maybeSingle(){return Promise.resolve({data:rows.length===1?rows[0]:null,error:table===failure?new Error('Unavailable'):null});},then(resolve,reject){return Promise.resolve({data:rows,error:table===failure?new Error('Unavailable'):null}).then(resolve,reject);}};return query;}};
}
const linked={id:'teacher-a',name:'Fixture',code:1,school_id:'school-a',user_id:'user-a',active:true};
test('teacher membership alone does not grant workspace access',async()=>{
 assert.equal(await verifiedAccess(fakeClient(),'user-a'),null);
 assert.equal(await verifiedAccess(fakeClient('teacher',[{...linked,active:false}]),'user-a'),null);
 assert.equal(await verifiedAccess(fakeClient('teacher',[{...linked,school_id:'school-b'}]),'user-a'),null);
 assert.equal(await verifiedAccess(fakeClient('teacher',[{...linked,user_id:'user-b'}]),'user-a'),null);
});
test('only the authenticated linked teacher is resolved',async()=>{
 const access=await verifiedAccess(fakeClient('teacher',[linked]),'user-a');
 assert.equal(access.role,'teacher');assert.equal(access.teacher.id,'teacher-a');assert.equal(access.schoolId,'school-a');
});
test('admin identity does not inherit a teacher identity',async()=>{
 const access=await verifiedAccess(fakeClient('admin',[linked]),'user-a');
 assert.equal(access.role,'admin');assert.equal(access.teacher,null);
});
test('database failures fail closed',async()=>{
 assert.equal(await verifiedAccess(fakeClient('teacher',[linked],'memberships'),'user-a'),null);
 assert.equal(await verifiedAccess(fakeClient('teacher',[linked],'teachers'),'user-a'),null);
});
