const test=require('node:test');
const assert=require('node:assert/strict');
const {yangonInputToISO,yangonInput,assignedAt}=require('../lib/teaching-types.ts');
test('Myanmar input conversion does not depend on browser timezone',()=>{
 assert.equal(yangonInputToISO('2026-10-25T09:00'),'2026-10-25T02:30:00.000Z');
 assert.equal(yangonInput('2026-10-25T02:30:59Z'),'2026-10-25T09:00');
 assert.throws(()=>yangonInputToISO('2026-02-30T09:00'));
 assert.throws(()=>yangonInputToISO('2026-10-25T25:00'));
 assert.throws(()=>yangonInputToISO('2026-10-25T09:00Z'));
});
test('dated assignment boundaries are inclusive start and exclusive end',()=>{
 const row={teacher_id:'teacher-a',class_id:'class-a',effective_from:'2026-10-25T00:00:00Z',effective_to:'2026-10-25T02:00:00Z'};
 assert.equal(assignedAt(row,'teacher-a','class-a','2026-10-25T00:00:00Z'),true);
 assert.equal(assignedAt(row,'teacher-a','class-a','2026-10-25T02:00:00Z'),false);
 assert.equal(assignedAt(row,'teacher-b','class-a','2026-10-25T01:00:00Z'),false);
 assert.equal(assignedAt(row,'teacher-a','class-b','2026-10-25T01:00:00Z'),false);
 assert.equal(assignedAt(row,'teacher-a','class-a','invalid'),false);
});
