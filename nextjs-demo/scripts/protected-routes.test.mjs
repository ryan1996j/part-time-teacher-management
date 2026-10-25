import test from 'node:test';
import assert from 'node:assert/strict';
const origin='http://127.0.0.1:3002';
for(const path of ['/admin/overview','/teacher/home','/legacy/index.html','/admin/reviews','/teacher/corrections','/admin/payroll','/admin/payments','/teacher/payments']){
 test(`anonymous and forged UI marker cannot enter ${path}`,async()=>{
  for(const cookie of ['', 'ai14-blue-demo-session=%7B%22role%22%3A%22admin%22%2C%22verified%22%3Atrue%7D']){
   const response=await fetch(origin+path,{redirect:'manual',headers:cookie?{cookie}:{}});
   assert.equal(response.status,307);
   assert.equal(new URL(response.headers.get('location'),origin).pathname,'/login');
   assert.match(response.headers.get('cache-control'),/no-store/);
  }
 });
}
