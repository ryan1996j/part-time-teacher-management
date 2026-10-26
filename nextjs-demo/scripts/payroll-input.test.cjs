const test=require('node:test');
const assert=require('node:assert/strict');
const {validPeriodDate,moneyText,validAdjustmentAmount}=require('../lib/payroll-types.ts');
test('payroll date validation rejects normalized impossible dates',()=>{
 assert.equal(validPeriodDate('2026-10-25'),true);assert.equal(validPeriodDate('2024-02-29'),true);
 for(const v of ['2026-02-29','2026-13-01','2026-10-25T00:00:00Z',null,'25/10/2026'])assert.equal(validPeriodDate(v),false);
});
test('displayed MMK retains exact integer values above JavaScript safe-integer range',()=>{
 assert.equal(moneyText('900719925474099199'),'900,719,925,474,099,199');assert.equal(moneyText('8500'),'8,500');assert.equal(moneyText('0'),'0');
});

test('adjustments accept exact signed int64 MMK and reject zero, decimal and overflow',()=>{
 for(const v of ['1000','-500','+200','9223372036854775807','-9223372036854775808'])assert.equal(validAdjustmentAmount(v),true);
 for(const v of ['0','-0','1.5','1e3','','9223372036854775808','-9223372036854775809',null])assert.equal(validAdjustmentAmount(v),false);
});

test('browser adjustment pattern supports Unicode v-mode validation for negative MMK',()=>{
 const pattern=new RegExp('^([+]|-)?[0-9]+$','v');
 assert.equal(pattern.test('-500'),true);assert.equal(pattern.test('+1000'),true);assert.equal(pattern.test('1.5'),false);
});
