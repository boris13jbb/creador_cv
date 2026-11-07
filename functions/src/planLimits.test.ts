import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {
  FREE_MAX_CVS,
  canCreateResume,
  isProEntitlement,
  maxCvsFor,
} from "./planLimits";

const NOW = new Date("2026-10-27T15:00:00.000Z");

describe("planLimits", () => {
  it("FREE_MAX_CVS es 3", () => {
    assert.equal(FREE_MAX_CVS, 3);
  });

  it("canCreateResume Free bloquea en el límite", () => {
    assert.equal(canCreateResume({currentCount: 2, isPro: false}), true);
    assert.equal(canCreateResume({currentCount: 3, isPro: false}), false);
    assert.equal(canCreateResume({currentCount: 100, isPro: true}), true);
    assert.equal(canCreateResume({currentCount: -1, isPro: false}), false);
  });

  it("maxCvsFor Pro es ilimitado práctico", () => {
    assert.ok(maxCvsFor(true) > FREE_MAX_CVS);
  });

  it("isProEntitlement stripe active/trialing", () => {
    assert.equal(
      isProEntitlement({plan: "pro", subscriptionStatus: "active"}, NOW),
      true,
    );
    assert.equal(
      isProEntitlement({plan: "pro", subscriptionStatus: "trialing"}, NOW),
      true,
    );
    assert.equal(
      isProEntitlement({plan: "pro", subscriptionStatus: "canceled"}, NOW),
      false,
    );
    assert.equal(
      isProEntitlement({plan: "free", subscriptionStatus: "active"}, NOW),
      false,
    );
    assert.equal(isProEntitlement(null, NOW), false);
  });

  it("admin_grant programado denegado; vigente permitido; vencido denegado", () => {
    const base = {
      plan: "pro",
      subscriptionStatus: "active",
      source: "admin_grant",
      grantModality: "temporary",
      grantStartsAt: "2026-10-27T15:00:00.000Z",
      grantExpiresAt: "2026-10-28T15:00:00.000Z",
    };
    assert.equal(
      isProEntitlement(base, new Date("2026-10-27T14:00:00.000Z")),
      false,
    );
    assert.equal(isProEntitlement(base, NOW), true);
    assert.equal(
      isProEntitlement(base, new Date("2026-10-28T15:00:00.000Z")),
      false,
    );
  });

  it("admin_grant vencido no da canCreate ilimitado", () => {
    const expired = {
      plan: "pro",
      subscriptionStatus: "active",
      source: "admin_grant",
      grantExpiresAt: "2026-10-01T00:00:00.000Z",
    };
    const isPro = isProEntitlement(expired, NOW);
    assert.equal(isPro, false);
    assert.equal(canCreateResume({currentCount: 10, isPro}), false);
  });

  it("admin_grant legado sin fechas sigue Pro", () => {
    assert.equal(
      isProEntitlement(
        {plan: "pro", subscriptionStatus: "active", source: "admin_grant"},
        NOW,
      ),
      true,
    );
  });

  it("admin_grant temporal con fecha inválida denegado", () => {
    assert.equal(
      isProEntitlement(
        {
          plan: "pro",
          subscriptionStatus: "active",
          source: "admin_grant",
          grantModality: "temporary",
          grantExpiresAt: "%%%",
        },
        NOW,
      ),
      false,
    );
  });
});
