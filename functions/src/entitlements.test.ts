import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {
  freeAfterCancel,
  mapSubscriptionToEntitlement,
} from "./entitlements";

describe("mapSubscriptionToEntitlement", () => {
  it("active → Pro", () => {
    const e = mapSubscriptionToEntitlement({
      uid: "u1",
      status: "active",
      customerId: "cus_1",
      subscriptionId: "sub_1",
      priceId: "price_1",
    });
    assert.equal(e.plan, "pro");
    assert.equal(e.subscriptionStatus, "active");
    assert.equal(e.source, "stripe");
    assert.equal(e.stripeCustomerId, "cus_1");
  });

  it("trialing → Pro con trialEndsAt", () => {
    const e = mapSubscriptionToEntitlement({
      uid: "u1",
      status: "trialing",
      trialEndUnix: 1_700_000_000,
    });
    assert.equal(e.plan, "pro");
    assert.equal(e.subscriptionStatus, "trialing");
    assert.ok(e.trialEndsAt?.startsWith("20"));
  });

  it("canceled / past_due → Free", () => {
    assert.equal(
      mapSubscriptionToEntitlement({uid: "u1", status: "canceled"}).plan,
      "free",
    );
    assert.equal(
      mapSubscriptionToEntitlement({uid: "u1", status: "past_due"}).plan,
      "free",
    );
  });

  it("freeAfterCancel marca canceled", () => {
    const e = freeAfterCancel("u9");
    assert.equal(e.uid, "u9");
    assert.equal(e.plan, "free");
    assert.equal(e.subscriptionStatus, "canceled");
  });
});
