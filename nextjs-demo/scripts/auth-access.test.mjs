import test from 'node:test';
import assert from 'node:assert/strict';
import {resolveAccess} from '../lib/auth-access.ts';
const admin={school_id:'school-a',role:'admin',active:true};
test('requires one active valid membership',()=>{
 assert.equal(resolveAccess(null),null);
 assert.equal(resolveAccess([]),null);
 assert.equal(resolveAccess([{...admin,active:false}]),null);
 assert.equal(resolveAccess([{...admin,role:'owner'}]),null);
 assert.deepEqual(resolveAccess([admin]),{schoolId:'school-a',role:'admin'});
 assert.deepEqual(resolveAccess([{...admin,role:'teacher'}]),{schoolId:'school-a',role:'teacher'});
});
test('does not silently choose a school or a role from conflicting rows',()=>{
 assert.equal(resolveAccess([admin,{...admin,school_id:'school-b'}]),null);
 assert.equal(resolveAccess([admin,{...admin,role:'teacher'}]),null);
});
