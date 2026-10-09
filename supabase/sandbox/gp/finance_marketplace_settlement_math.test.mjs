import test from "node:test";
import assert from "node:assert/strict";
// Pure QA-only settlement arithmetic. No network, Stripe calls or persistent state.
function split({foodSatang,gpBasisSatang,gpBps,discountSatang=0,deliverySatang=0}){
  for(const n of [foodSatang,gpBasisSatang,gpBps,discountSatang,deliverySatang]) assert.ok(Number.isSafeInteger(n)&&n>=0);
  assert.ok(gpBps<=10000 && discountSatang<=foodSatang);
  assert.ok(gpBasisSatang<=foodSatang-discountSatang,"GP basis cannot exceed collected food");
  const collected=foodSatang-discountSatang;
  const gp=Math.floor((gpBasisSatang*gpBps+5000)/10000);
  const merchant=collected-gp;
  assert.ok(merchant>=0);
  assert.equal(merchant+gp,collected);
  return {collected,gp,merchant,deliveryExcluded:deliverySatang};
}
const cases=[
  ["zero GP",{foodSatang:10000,gpBasisSatang:10000,gpBps:0},0,10000],
  ["ten percent",{foodSatang:10000,gpBasisSatang:10000,gpBps:1000},1000,9000],
  ["half satang rounding",{foodSatang:101,gpBasisSatang:101,gpBps:5000},51,50],
  ["merchant funded discount basis",{foodSatang:10000,discountSatang:2000,gpBasisSatang:8000,gpBps:1000},800,7200],
  ["delivery excluded",{foodSatang:10000,gpBasisSatang:10000,gpBps:1000,deliverySatang:4000},1000,9000],
  ["full discount",{foodSatang:10000,discountSatang:10000,gpBasisSatang:0,gpBps:1000},0,0],
];
for(const [name,input,gp,merchant] of cases)test(name,()=>{const r=split(input);assert.equal(r.gp,gp);assert.equal(r.merchant,merchant)});
for(const [name,input] of [
  ["negative amount",{foodSatang:-1,gpBasisSatang:0,gpBps:0}],
  ["rate over 100%",{foodSatang:100,gpBasisSatang:100,gpBps:10001}],
  ["invalid discount",{foodSatang:100,discountSatang:101,gpBasisSatang:0,gpBps:0}],
  ["GP exceeds collected basis",{foodSatang:100,discountSatang:20,gpBasisSatang:100,gpBps:1000}],
  ["fractional satang",{foodSatang:100.5,gpBasisSatang:100,gpBps:1000}],
])test("reject "+name,()=>assert.throws(()=>split(input)));
