# solid-activity

Rails 8 demo: authenticated activity feed showcasing Solid Queue, Solid Cache, and Solid Cable.

## Setup

```sh
bundle install
bin/rails db:prepare
```

## Run

```sh
bin/dev   # or: bin/rails server + bin/jobs in a second terminal
```

Open http://localhost:3000 — sign up (or sign in) to use the feed.

Mission Control: http://localhost:3000/jobs (`admin` / `solid` by default)

## What to notice

- New posts appear as pending (Queue callout), then flip to ready over Cable
- Ready posts show a Cache callout and are fragment-cached
- Recurring purge removes pending posts older than 15 minutes

## Tests

```sh
bin/rails test
bin/rails test:system
```
