# Content roles and the review workflow

Decided before the rules, studio and emails are built, so all three implement the same contract.

## Roles

Roles are **custom claims on the Auth token**, set only with the Admin SDK. They are never fields on `users/{uid}`: anything a client can write there, a client can grant itself.

**How to give someone a role.** They first create an account in the app like any student. Then an admin opens **Content studio → Team**, enters their email, picks Writer or Reviewer and either "All subjects" or specific subjects, and saves. That writes a request to `staffInvites/{email}` (admin-only in the rules). `tools/admin/apply_roles.js`, run every 15 minutes by the notify-drafts workflow, sets the claims and marks the request applied. The person then signs out and in again. If the email has no account yet, the request waits and applies as soon as they sign up. `tools/admin/set_role.js --email=… --role=writer|reviewer|none [--subjects=Mathematics,Physics]` does the same immediately from a terminal.

| Claim | Can |
|---|---|
| `writer` | Create and edit items that aren't published, upload images, comment, submit for review, start a revision of a published item |
| `reviewer` | Everything a writer can, plus approve and publish, request changes, unpublish, delete, reorder, handle problem reports |
| `admin` (existing) | Everything a reviewer can; the only role that can be set up by `create_admin_user.js` |

Rule helpers: `isWriter()` = writer ∨ reviewer ∨ admin; `isReviewer()` = reviewer ∨ admin.

**Subjects.** A writer or reviewer may be limited to some subjects: the `subjects` claim lists their ids. No `subjects` claim means every subject; an admin is never limited. The rules' `writes(subjectId)` / `reviews(subjectId)` check the role *and* the subject on every lesson write, version, comment, lesson-count update, question fix and subject-index rebuild, and an update checks both the old and new `subjectId`, so nothing can be moved out of scope. Outside their subjects a team member can still read everything in the studio, but the editor shows it read-only. Problem reports themselves (`flags`) can be closed by any reviewer; fixing a question's answer is checked against the question's subject.

In the app, `staffAccessProvider` (a `StaffAccess`: role plus subjects, with `roleIn(subjectId)`) reads the claims **for the UI only**. The rules are the protection.

A role change reaches a signed-in session only after a token refresh (up to an hour) or a fresh sign-in, as with `admin` today.

## Status of a lesson item

```
draft ──submit──▶ in_review ──approve──▶ published
  ▲                  │
  └──changes_requested◀┘ (reviewer asks for changes)
```

- Only the exact string `published` is visible to students (the rule and `ResourceStatus.parse`, unchanged).
- A writer may write an item whose **current and new** status are both among `draft`, `in_review` and `changes_requested`, and may move it `draft → in_review` or `changes_requested → in_review`.
- Only a reviewer may set `published` or `changes_requested`, or change anything about a published item.

## Editing something already published: revisions

A writer never edits a published item in place, because every keystroke would go live. Instead:

1. **Start revision** creates a new draft `{…copy, revisionOf: <publishedId>, status: 'draft'}`.
2. It goes through review like any draft.
3. **Approve** (reviewer), in one batch:
   - Copy the revision's content fields into the published document. **The id is kept, so students' completion ticks survive.**
   - Write the old content to the original's `versions`.
   - Delete the revision.

## Supporting documents

| Path | Holds | Access |
|---|---|---|
| `…/resources/{r}/versions/{v}` | `{body, title, …content fields, savedAt, savedBy}` | staff read; written by every save |
| `…/resources/{r}/comments/{c}` | `{authorUid, authorName, text, createdAt, resolved}` | staff read/write; author edits own |

## Emails (`notify_drafts.js`, every 15 minutes)

| Transition | Goes to |
|---|---|
| → `in_review` | reviewers (`NOTIFY_TO`) |
| → `changes_requested` | the writer (email via Admin SDK `getUser(createdBy)`) |
| → `published` | the writer |

Each item stores `notifiedStatus`, and an email is sent only when `status != notifiedStatus`. So each transition emails once, and a failed send is retried. Problem reports stay in the same digest.
