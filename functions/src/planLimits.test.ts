import test from "node:test";
import assert from "node:assert/strict";
import {
  FREE_MAX_CVS,
  canCreateResume,
  isProEntitlement,
  maxCvsFor,
} from "./planLimits";

test("FREE_MAX_CVS es 3", () => {
  assert.equal(FREE_MAX_CVS, 3);
});

test("canCreateResume Free bloquea en el límite", () => {
  assert.equal(canCreateResume({currentCount: 2, isPro: false}), true);
  assert.equal(canCreateResume({currentCount: 3, isPro: false}), false);
  assert.equal(canCreateResume({currentCount: 100, isPro: true}), true);
  assert.equal(canCreateResume({currentCount: -1, isPro: false}), false);
});

test("maxCvsFor Pro es ilimitado práctico", () => {
  assert.equal(maxCvsFor(false), 3);
  assert.ok(maxCvsFor(true) > 1000);
});

test("isProEntitlement solo active/trialing", () => {
  assert.equal(
    isProEntitlement({plan: "pro", subscriptionStatus: "active"}),
    true,
  );
  assert.equal(
    isProEntitlement({plan: "pro", subscriptionStatus: "trialing"}),
    true,
  );
  assert.equal(
    isProEntitlement({plan: "pro", subscriptionStatus: "canceled"}),
    false,
  );
  assert.equal(
    isProEntitlement({plan: "free", subscriptionStatus: "active"}),
    false,
  );
  assert.equal(isProEntitlement(null), false);
});
