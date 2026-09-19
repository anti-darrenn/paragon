# Maintenance jobs — running server work without Blaze

## The short answer

**You don't need Blaze, and you don't need to leave Firebase.**

Blaze isn't a feature. It's the billing plan that unlocks **Cloud
Functions** — Google-hosted compute. Everything we wanted Functions for
(reaping stale guest accounts, cleaning orphaned documents, computing
streaks the client isn't trusted to compute) is ordinary `firebase-admin`
code. The Admin SDK **bypasses security rules** and runs anywhere Node
runs. Cloud Functions only supplies a place to run it and a trigger.

So the jobs live in `jobs.js` and run from a free scheduler instead.
Firestore, Auth and the Admin SDK all work on the free **Spark** plan.

## What this genuinely can't do

Cloud Functions fire **on an event** — a document write, an account
deletion — within milliseconds. A scheduled job can't. Anything needing
real-time server authority (rejecting a bad write *as it happens*) still
needs Functions or an always-on server.

For derived values this doesn't matter. `attempts.timestamp` is a server
timestamp and is the source of truth, so recomputing streaks on a
schedule is correct — just eventually rather than instantly. Security
rules do the real-time half: they constrain what a client may write, and
this job decides what's actually true.

## Requirements

| Need | Detail |
|---|---|
| Node | 18 or newer |
| Package | `firebase-admin` (already used by the scraper) |
| Credentials | A service account JSON with Firestore + Auth admin rights |
| Scheduler | Anything that can run a command on a timer |
| Firebase plan | **Spark (free) is sufficient** |

Credentials are read, in order, from:

1. `FIREBASE_SERVICE_ACCOUNT` — the JSON *contents* (use this in CI)
2. `GOOGLE_APPLICATION_CREDENTIALS` — a path to the JSON
3. `../scraper/data/serviceAccountKey.json` — the local fallback

**Never commit the key.** It grants full admin access and bypasses every
security rule. In GitHub Actions it belongs in repository secrets.

## The real constraint is Spark's quotas, not Functions

| Quota | Spark daily limit |
|---|---|
| Document reads | 50,000 |
| Document writes | 20,000 |
| Deletes | 20,000 |
| Stored data | 1 GiB |

`--job=streaks` reads every user's recent attempts, so its cost scales
with users × their activity. At a few hundred students it's comfortable;
at a few thousand it will eat the read quota and should move to an
incremental design (only users with attempts since the last run). The
other two jobs are cheap.

This quota ceiling — not Cloud Functions — is what will eventually push
you to Blaze. Worth knowing that's the actual trigger.

## Running it

Dry run by default. Nothing is written without `--apply`.

```bash
cd tools/admin
npm install

node jobs.js --job=guests --days=30    # what would be deleted
node jobs.js --job=guests --days=30 --apply

node jobs.js --job=orphans --apply
node jobs.js --job=streaks --apply
node jobs.js --job=all --apply
```

Always run a dry run first on production data.

## Scheduling it free

`.github/workflows/maintenance.yml` runs all three nightly on GitHub
Actions — free for public repos, 2,000 minutes/month on a free private
one. These jobs take seconds.

Equally fine: a `cron` entry on any machine that's usually on, or a free
tier on Fly.io / Render. The script doesn't care.

## If you did want off Firebase entirely

The genuinely open-source equivalents are **Supabase** (Postgres +
GoTrue + realtime, self-hostable), **Appwrite**, and **PocketBase** (a
single Go binary). All three are credible, and all three are a *full
rewrite* of the data layer, the auth layer and the security rules — not a
drop-in. Given every problem on the current list is solvable with a cron
job and a service account, a migration would be a large cost for no gain
today. Worth revisiting only if Firebase pricing or lock-in becomes the
actual problem.
