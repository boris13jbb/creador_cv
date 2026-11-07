import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {
  isAdminGrantActiveInWindow,
  isAdminGrantPastExpiry,
  parseGrantInstant,
} from "./grantAccessPolicy";

const NOW = new Date("2026-10-27T15:00:00.000Z");

describe("parseGrantInstant", () => {
  it("ausente / inválido / ok", () => {
    assert.equal(parseGrantInstant(null).kind, "absent");
    assert.equal(parseGrantInstant("").kind, "invalid");
    assert.equal(parseGrantInstant("no-fecha").kind, "invalid");
    assert.equal(parseGrantInstant("2026-10-27T15:00:00.000Z").kind, "ok");
  });
});

describe("isAdminGrantActiveInWindow", () => {
  it("legado sin fechas: permitido", () => {
    assert.equal(
      isAdminGrantActiveInWindow(
        {source: "admin_grant", plan: "pro", subscriptionStatus: "active"},
        NOW,
      ),
      true,
    );
  });

  it("programado: denegado antes del inicio; permitido en el inicio", () => {
    const data = {
      source: "admin_grant",
      plan: "pro",
      subscriptionStatus: "active",
      grantModality: "temporary",
      grantStartsAt: "2026-10-27T15:00:00.000Z",
      grantExpiresAt: "2026-10-28T15:00:00.000Z",
    };
    assert.equal(
      isAdminGrantActiveInWindow(
        data,
        new Date("2026-10-27T14:59:59.999Z"),
      ),
      false,
    );
    assert.equal(isAdminGrantActiveInWindow(data, NOW), true);
  });

  it("durante el intervalo: permitido; en el vencimiento: denegado", () => {
    const data = {
      source: "admin_grant",
      plan: "pro",
      subscriptionStatus: "active",
      grantExpiresAt: "2026-10-27T16:00:00.000Z",
      grantStartsAt: "2026-10-27T14:00:00.000Z",
    };
    assert.equal(isAdminGrantActiveInWindow(data, NOW), true);
    assert.equal(
      isAdminGrantActiveInWindow(
        data,
        new Date("2026-10-27T16:00:00.000Z"),
      ),
      false,
    );
    assert.equal(
      isAdminGrantActiveInWindow(
        data,
        new Date("2026-10-27T17:00:00.000Z"),
      ),
      false,
    );
  });

  it("fecha inválida en temporal: denegado", () => {
    assert.equal(
      isAdminGrantActiveInWindow(
        {
          source: "admin_grant",
          plan: "pro",
          subscriptionStatus: "active",
          grantModality: "temporary",
          grantExpiresAt: "no-es-fecha",
        },
        NOW,
      ),
      false,
    );
  });

  it("temporal sin expires: denegado", () => {
    assert.equal(
      isAdminGrantActiveInWindow(
        {
          source: "admin_grant",
          plan: "pro",
          subscriptionStatus: "active",
          grantModality: "temporary",
        },
        NOW,
      ),
      false,
    );
  });

  it("stripe no usa esta función vía isProEntitlement path", () => {
    assert.equal(
      isAdminGrantActiveInWindow(
        {source: "stripe", plan: "pro", subscriptionStatus: "active"},
        NOW,
      ),
      false,
    );
  });
});

describe("isAdminGrantPastExpiry", () => {
  it("no marca programados como vencidos", () => {
    assert.equal(
      isAdminGrantPastExpiry(
        {
          source: "admin_grant",
          grantStartsAt: "2026-11-01T00:00:00.000Z",
          grantExpiresAt: "2026-11-08T00:00:00.000Z",
        },
        NOW,
      ),
      false,
    );
  });

  it("marca vencidos", () => {
    assert.equal(
      isAdminGrantPastExpiry(
        {
          source: "admin_grant",
          grantExpiresAt: "2026-10-01T00:00:00.000Z",
        },
        NOW,
      ),
      true,
    );
  });
});
