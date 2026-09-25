# Content roles and the review workflow

Decided before the rules, studio and emails are built, so all three implement the same contract.

## Roles

Roles are **custom claims on the Auth token**, set only with the Admin SDK by `tools/admin/set_role.js --email=… --role=writer|reviewer|none`. They are never fields on `users/{uid}`: anything a client can write there, a client can grant itself.

| Claim | Can |
|---|---|
| `writer` | Create and edit items that aren't published, upload images, comment, submit for review, start a revision of a published item |
| `reviewer` | Everything a writer can, plus approve and publish, request changes, unpublish, delete, reorder, handle problem reports |
| `admin` (existing) | Everything a reviewer can; the only role that can be set up by `create_admin_user.js` |

Rule helpers: `isWriter()` = writer ∨ reviewer ∨ admin; `isReviewer()` = reviewer ∨ admin. In the app, `staffRoleProvider` reads the claims **for the UI only**. The rules are the protection.

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
