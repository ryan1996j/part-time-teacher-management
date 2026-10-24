import test from 'node:test';
import assert from 'node:assert/strict';
import {createDemoSession,demoDestination,DEMO_SESSION_KEY} from '../lib/demo-session.ts';
test('Admin demo maps to existing role identity and Next route',()=>{assert.deepEqual(createDemoSession('admin','fixed'),{role:'admin',teacherId:null,name:'School Admin',verified:true,at:'fixed'});assert.equal(demoDestination('admin'),'/admin/overview')});
test('Teacher demo remains linked to T001 and own home',()=>{const s=createDemoSession('teacher','fixed');assert.equal(s.teacherId,'T001');assert.equal(s.role,'teacher');assert.equal(s.name,'Aye Aye Win');assert.equal(demoDestination('teacher'),'/teacher/home');assert.equal(DEMO_SESSION_KEY,'ai14-blue-demo-session')});
