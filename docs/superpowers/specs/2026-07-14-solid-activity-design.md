# solid-activity — Design Spec

**Date:** 2026-07-14  
**Location:** `/Users/mattpolito/Work/solid-activity`  
**Stack:** Rails 8 · Hotwire · Solid Queue · Solid Cache · Solid Cable · SQLite

## Goal

A showcase-first Rails 8 demo: a thin but realistic **authenticated activity feed** (posts + comments) that clearly exercises the Solid stack. UI callouts name which Solid piece is in play; Mission Control Jobs provides Queue visibility. Not a multi-page playground hub — one coherent product surface with educational labels.

## Architecture

- **App shape:** Rails 8 monolith with stock Solid defaults (multi-DB SQLite for app, queue, cache, cable).
- **Frontend:** Hotwire (Turbo Drive, Frames, Streams) + Stimulus.
- **Auth:** Rails 8 generated authentication (sessions, cookie-based).
- **Ops:** Mission Control Jobs mounted at `/jobs` for Solid Queue.
- **Showcase:** Subtle UI callouts on the feed (“via Solid Cable”, “processing via Solid Queue”, “cached via Solid Cache”) — not separate demo pages.

```
Browser (Hotwire)
    → Rails app (Auth · Posts · Comments · Feed + showcase callouts)
        → Solid Cable  — live Turbo Streams
        → Solid Queue  — enrich + recurring purge
        → Solid Cache  — feed fragment / Russian-doll caching
    → SQLite (app + queue + cache + cable)
```

## Domain model

### User
- `email`, `password_digest` (and other columns from Rails 8 auth generator)
- `has_many :sessions`
- `has_many :posts`, `has_many :comments`

### Session
- Cookie-based sessions from Rails 8 authentication generator

### Post
- `body` (required)
- `summary` (nullable; filled by enrichment job)
- `status` enum/string: `pending` → `ready`, or `failed` after job retries are exhausted
- `belongs_to :user`
- `has_many :comments`
- Touched on comment create for cache invalidation

### Comment
- `body` (required)
- `belongs_to :user`, `belongs_to :post`

## Components & Solid touchpoints

| Component | Responsibility |
|-----------|----------------|
| `EnrichPostJob` | Solid Queue: build a short summary with a **local heuristic** (truncate/`strip` first ~140 chars of `body` — no external API), set `status: ready`, then broadcast |
| `PurgeStalePendingPostsJob` | Solid Queue recurring: **destroy** posts still `pending` older than **15 minutes** |
| Activity Turbo Stream | Solid Cable: stream name e.g. `activity` for ready posts and new comments |
| Feed partials | Solid Cache: fragment / Russian-doll caching keyed with digests; bust via `touch` |
| Mission Control | Operator UI for Queue |
| Showcase callouts | Labeled hints on feed UI for Queue / Cache / Cable |

## Data flow

### Create post
1. Authenticated user submits post (Turbo) → `PostsController#create`
2. Save `Post` with `status: pending`; respond with Turbo Stream (or redirect) that inserts a “processing…” feed row (Queue callout) — server-rendered pending state, not client-only optimism
3. Enqueue `EnrichPostJob`
4. Job writes `summary` via local heuristic, sets `status: ready`, touches for cache
5. Broadcast via Solid Cable → Turbo Stream **replace** the pending row with the ready partial on stream `activity`
6. Later full-page loads serve the item from Solid Cache fragments (Cache callout)

### Create comment
1. Save comment → Turbo Stream append under post (Cable)
2. `touch` parent post for cache bust

### Recurring cleanup
- `PurgeStalePendingPostsJob` destroys posts still `pending` and older than 15 minutes (second Queue pattern for the showcase)

## Error handling

- Sign up + sign in via Rails 8 auth generator; unauthenticated users redirected to sign-in
- Only owners may destroy their posts/comments
- Blank body → re-render with errors (422 / Turbo)
- `EnrichPostJob` retries via Solid Queue; after exhaustion set `status: failed` and replace the feed row with a visible failed partial (not silent hang)
- Recurring purge destroys stuck `pending` posts older than 15 minutes
- Cable disconnect: full page refresh still works; live updates resume on reconnect
- Cache misses are acceptable; update/destroy expire via `touch` / explicit expire

## Testing

- **Framework:** Minitest (Rails default)
- **Coverage:**
  - Model validations and associations
  - Request/controller coverage for auth, create post, create comment
  - Job tests for `EnrichPostJob` and `PurgeStalePendingPostsJob`
  - 1–2 system tests: sign in, create post, see ready feed item

## Out of scope

- RSpec / FactoryBot stack
- Email, Active Storage, Action Mailbox
- Multi-tenant rooms / DMs / presence
- Redis, Sidekiq, Postgres (Solid + SQLite only)
- Production deploy / Kamal (optional later)

## Approach rationale

Chose **showcase-first with thin domain** over a pure product feed or a multi-surface hub: one realistic feed, educational callouts, Mission Control for Queue depth — maximum teaching signal without splitting into disconnected mini-apps.

## Success criteria

- New Rails 8 app boots with Solid Queue, Cache, and Cable configured
- User can sign up/in, create posts and comments
- Posts go `pending` → enriched `ready` via Queue and appear live via Cable
- Feed items are fragment-cached; UI callouts name Queue / Cache / Cable
- Recurring purge job is registered and testable
- Mission Control Jobs is reachable for operators
- Automated tests above are green
