// node notify_drafts.test.js — the report cursor cannot be pushed into the future.
const assert = require("assert");
const { usableCursor } = require("./notify_drafts");

const ts = (ms) => ({ toMillis: () => ms, toDate: () => new Date(ms) });
const now = ts(Date.parse("2026-10-16T12:00:00Z"));

// A cursor dated after now can only come from a forged report: dropped.
assert.strictEqual(usableCursor(ts(Date.parse("9999-01-01T00:00:00Z")), now), null);
assert.strictEqual(usableCursor(ts(now.toMillis() + 1), now), null);
// No cursor, or not a timestamp, is no cursor.
assert.strictEqual(usableCursor(null, now), null);
assert.strictEqual(usableCursor("2026-10-16", now), null);
// Control: a past or present cursor is kept as it is.
const past = ts(Date.parse("2026-10-15T09:00:00Z"));
assert.strictEqual(usableCursor(past, now), past);
assert.strictEqual(usableCursor(now, now), now);

console.log("notify_drafts: all checks passed");
