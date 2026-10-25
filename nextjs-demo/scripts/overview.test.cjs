const test=require('node:test');
const assert=require('node:assert/strict');
const {activityWindow,addActivity}=require('../lib/overview-data.ts');
test('overview uses seven Myanmar dates across UTC midnight boundaries',()=>{
 const before=activityWindow('2026-10-24T17:29:59Z'),after=activityWindow('2026-10-24T17:30:00Z');
 assert.equal(before.to,'2026-10-24');assert.equal(after.to,'2026-10-25');assert.equal(after.from,'2026-10-19');
 assert.equal(after.dates.length,7);assert.equal(after.start,'2026-10-18T17:30:00.000Z');assert.equal(after.end,'2026-10-25T17:30:00.000Z');
});
test('completed activity excludes open and out-of-range rows, attributes overnight time to start date and accumulates pages',()=>{
 const w=activityWindow('2026-10-25T03:00:00Z'),minutes=Array(7).fill(0);
 addActivity(minutes,w.dates,[
  {start_at:'2026-10-24T17:00:00Z',end_at:'2026-10-24T18:00:00Z',minutes:60},
  {start_at:'2026-10-24T17:30:00Z',end_at:'2026-10-24T18:00:00Z',minutes:30},
  {start_at:'2026-10-25T01:00:00Z',end_at:null,minutes:null},
  {start_at:'2026-10-25T01:00:00Z',end_at:'2026-10-25T01:00:15Z',minutes:0},
  {start_at:'2026-10-18T01:00:00Z',end_at:'2026-10-18T02:00:00Z',minutes:60},
 ]);
 assert.deepEqual(minutes,[0,0,0,0,0,60,30]);
 addActivity(minutes,w.dates,[{start_at:'2026-10-25T01:00:00Z',end_at:'2026-10-25T01:30:00Z',minutes:30}]);assert.equal(minutes[6],60);
});
