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

## Live quiz rooms (Wave H, 2026-10-15)

A game with 30 players and 20 questions, worked out from the listeners each screen holds:

| Who | Listens to | Reads |
| --- | --- | ---: |
| Host | the room (≈ 42 changes), players (30 joins), answers (600) | ≈ 670 |
| Each player | the room only (≈ 42 changes), plus their own player and answer once after a reload | ≈ 45 × 30 ≈ 1,350 |
| Everyone | the 20 questions, read once (keyed by the ids, not the room) | 31 × 20 ≈ 620 |
| **Total** | | **≈ 2,600 reads** |

The writes are about 650: 30 joins, 600 answers, and the host's transitions.

So a classroom game costs about 5% of Spark's daily reads. Players never listen to each
other or to the answers, or 30 phones would cost about 18,000 reads. Rooms never touch
`attempts` or `progress`.

**Rooms v2 (2026-10-17), worked out, not yet measured.** The room document now also changes
once more per question (the reveal carries the scores), so each phone reads about 20 more
changes a game: about 600 more reads for 30 players, so about **3,200 reads** a game.
A host's own quiz is one read per phone (`quizzes/{id}`), and its diagrams one each. The
end of a game adds one `quizHistory` write per player and the host (31). A profile photo is
read once by the host per player who has one.
