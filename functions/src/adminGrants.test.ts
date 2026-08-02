import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {buildAdminGrant, isActiveAdminGrant} from "./adminGrants";

describe("adminGrants", () => {
  it("buildAdminGrant crea Pro con source admin_grant", () => {
    const g = buildAdminGrant({
      uid: "u1",
      adminUid: "admin1",
      note: "Cliente piloto",
    });
    assert.equal(g.plan, "pro");
    assert.equal(g.subscriptionStatus, "active");
    assert.equal(g.source, "admin_grant");
    assert.equal(g.grantedBy, "admin1");
    assert.equal(g.grantNote, "Cliente piloto");
    assert.equal(g.grantExpiresAt, null);
  });

  it("isActiveAdminGrant respeta expiración", () => {
    const now = new Date("2026-08-01T12:00:00.000Z");
    assert.equal(
      isActiveAdminGrant(
        {
          source: "admin_grant",
          plan: "pro",
          subscriptionStatus: "active",
          grantExpiresAt: "2026-08-02T00:00:00.000Z",
        },
        now,
      ),
      true,
    );
    assert.equal(
      isActiveAdminGrant(
        {
          source: "admin_grant",
          plan: "pro",
          subscriptionStatus: "active",
          grantExpiresAt: "2026-07-01T00:00:00.000Z",
        },
        now,
      ),
      false,
    );
  });

  it("buildAdminGrant rechaza expiresAt pasada", () => {
    assert.throws(() =>
      buildAdminGrant({
        uid: "u1",
        adminUid: "a1",
        expiresAt: "2020-01-01T00:00:00.000Z",
        now: new Date("2026-08-01T00:00:00.000Z"),
      }),
    );
  });
});
