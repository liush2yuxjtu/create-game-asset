import test from 'node:test';import assert from 'node:assert/strict';import {sampleRehearsal as s} from '../src/rehearsal.js';
test('visual hit fires at 1.20 only; seeking never accumulates damage',()=>{assert.equal(s(1.19).health,100);assert.equal(s(1.2).health,64);assert.equal(s(2.5).health,64);assert.equal(s(.8).health,100);assert.equal(s(1.2).health,64);});
test('result waits for cleanup; rejects invalid time',()=>{assert.equal(s(3.19).complete,false);assert.equal(s(3.2).complete,true);assert.equal(s(-1).health,100);assert.throws(()=>s(NaN),TypeError);});
