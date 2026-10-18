# Booking Domain Invariants — booking-api

> **Constitutional force**: these invariants are referenced by constitution principle V
> (`.specify/memory/constitution.md`). A violation is treated exactly like a violation of
> the constitution. Each invariant states the rule, the forbidden operation, and the
> approved alternative. Changing this file is a constitutional amendment.

## 1. No Double Booking

Two active (non-cancelled) bookings on the same resource MUST NOT overlap. Intervals are
half-open — `[start, end)` — so a booking ending at 10:00 and one starting at 10:00 do not
overlap. The rule MUST hold under concurrent requests: it is enforced in application code
AND by the database, never by an application-side read-then-write check alone.

**Forbidden**: accepting a booking after a non-locking availability check; relying on
request ordering to avoid races.
**Approved alternative**: reject the conflicting request with a conflict error; the caller
chooses another slot.

**Rationale**: a double-booked resource is the one failure a booking system exists to
prevent, and races are exactly where agent-written code is weakest.

## 2. Time Is UTC

Every instant is stored and compared in UTC. For every booking and time slot, `start < end`.
The API accepts and returns instants as ISO 8601 with an explicit offset; local time and
offset-less timestamps never reach persistence.

**Forbidden**: `DateTime.Now`, unspecified-kind `DateTime` values in persistence, comparing
instants across time zones without normalizing.
**Approved alternative**: normalize to UTC at the API boundary; convert to local time only
for display, outside this service.

**Rationale**: a time zone error moves a booking silently, and no test on the author's
machine catches it.

## 3. Booking Lifecycle

Booking status changes follow one defined state machine (for example Pending → Confirmed →
Cancelled / Completed); the exact states and transitions are fixed by the feature that
introduces bookings and live in one place in code. Terminal states are final. A booking in a
terminal state is never edited.

**Forbidden**: setting a status directly without the transition check; editing a cancelled
or completed booking; a second, divergent transition table.
**Approved alternative**: a new booking (rebook) instead of reviving a terminal one.

**Rationale**: a lifecycle enforced in one place is auditable; one enforced ad hoc per
endpoint diverges.

## 4. Bookings Are Never Deleted

A booking is never physically deleted. Cancellation is a status transition that records who
cancelled, when, and why.

**Forbidden**: `DELETE` of a booking row, by code, migration, or rollback.
**Approved alternative**: the cancellation transition (invariant 3).

**Rationale**: booking history is the evidence for disputes and reporting; a deleted
booking cannot be explained afterwards.

## 5. Bookable Only Within a Slot

A booking MUST fall entirely inside an open time slot of an active resource. A retired
(soft-deleted) resource accepts no new bookings, but its existing bookings and history stay
readable.

**Forbidden**: bookings outside any slot, spanning a slot boundary, or against a retired
resource; hard-deleting a resource or slot that bookings reference.
**Approved alternative**: open or extend a slot first (an explicit operation), then book.

**Rationale**: slots are the resource owner's statement of availability; bypassing them
books time nobody offered.

## Rollback interaction

Reverting code or a migration MUST NOT cascade into physical deletion of bookings
(invariant 4) or of resources and slots that bookings reference. If a rollback would touch
them, stop and report (`docs/sdlc/rollback-process.md`).
