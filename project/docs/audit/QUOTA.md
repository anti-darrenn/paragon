# Firestore reads per flow, and the daily ceiling

The Spark plan allows **50,000 reads and 20,000 writes a day**, shared by every student.
The day is the *Pacific* calendar day, so it resets at 08:00 in Lagos (09:00 in
northern-hemisphere winter). When the quota runs out:
- every request fails with `resource-exhausted`;
- the app shows its "very busy" banner (`lib/core/data/quota_status.dart`);
- the studio's **Daily quota** panel (from `tools/admin/usage.js`) shows how close
  today is.

Hosting reads are not Firestore reads and are not counted here.

## How to measure

Use a debug build: `flutter run -d chrome`.
1. A pill in the bottom-left corner shows `reads <this screen> · <total>`, and the
   console prints every billed read.
2. Long-press the pill to reset it, then walk one flow.
3. Tap the pill to copy a per-screen table, and paste it below.

Only server answers are counted, because cache hits are free. A read is counted as
Firestore bills it: one per document returned, one for an empty result, one per
`count()`.

## Estimate from the code (2026-10-03, before measurement)

The flow is a new student on a fresh browser. It goes welcome → guest → one subject's
course page → a topic → one lesson → the topic test → a drill.

| Step | Reads | Notes |
| --- | ---: | --- |
| Welcome | ~6 | `subjects` (question counts) |
| Dashboard | ~4–8 | user, progress and learn docs; weekly `count()` |
| Course page | ~50–75 | units, then topics per unit: the largest browse cost |
| Topic overview | ~4–8 | published resources |
| Lesson | ~2–5 | resources (shared), `subjectIndex` (1), figures |
| Topic test | ~10–20 | 10 questions; a wrap-around query can double it |
| Drill | ~20–40 | 20 questions; same wrap-around |
| **Session** | **~100–160** | |
| Each extra subject browsed | +50–75 | |

**Ceiling at this estimate:** 50,000 / ~130 ≈ **380 sessions a day**, fewer if
students browse several subjects. Writes are about 1 per answer plus a few per
session, so 20k writes is about 15–20k answers a day. Reads run out first.

## Fixed

- **Course outlines are cache-first** (`lib/core/data/cache_first.dart`).
  - `subjects`, `units` and `topics` are answered from the device's Firestore cache
    when this browser fetched the same query from the server in the last 12 hours,
    and the cache still holds every document.
  - A returning student re-opening a course now costs about 0 reads for the outline,
    where it used to cost 50–75.
  - The cost is that a topic's lesson count can lag a publish by up to 12 hours.

## Measured

_To fill in from the read meter on a production-data debug build._

| Flow | Reads, first visit | Reads, return visit |
| --- | ---: | ---: |
| Welcome → guest → dashboard | | |
| Course page (Physics, 64 topics) | | |
| Topic → lesson | | |
| Topic test | | |
| Drill | | |
| WAEC exam setup + 40-question exam | | |
| Review / mistakes notebook | | |
