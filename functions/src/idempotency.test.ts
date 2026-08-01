import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {
  isAlreadyExistsError,
  isHandledBillingEvent,
  shouldProcessClaim,
} from "./idempotency";

describe("idempotency helpers", () => {
  it("detecta already-exists gRPC y string", () => {
    assert.equal(isAlreadyExistsError({code: 6}), true);
    assert.equal(isAlreadyExistsError({code: "already-exists"}), true);
    assert.equal(isAlreadyExistsError({code: "permission-denied"}), false);
    assert.equal(isAlreadyExistsError({}), false);
  });

  it("claimed false = no reprocesar", () => {
    assert.equal(shouldProcessClaim(true), true);
    assert.equal(shouldProcessClaim(false), false);
  });

  it("solo eventos de billing conocidos", () => {
    assert.equal(isHandledBillingEvent("checkout.session.completed"), true);
    assert.equal(isHandledBillingEvent("customer.subscription.deleted"), true);
    assert.equal(isHandledBillingEvent("invoice.payment_failed"), true);
    assert.equal(isHandledBillingEvent("charge.succeeded"), false);
  });
});
