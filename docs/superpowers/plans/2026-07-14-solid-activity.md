# solid-activity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Rails 8 authenticated activity feed demo that showcases Solid Queue, Solid Cache, and Solid Cable with educational UI callouts.

**Architecture:** Single Rails 8 monolith at `/Users/mattpolito/Work/solid-activity` using stock Solid + SQLite multi-DB. Posts save as `pending`, `EnrichPostJob` enriches and broadcasts via Turbo Streams over Solid Cable; feed partials use Solid Cache; a recurring purge job demonstrates a second Queue pattern; Mission Control Jobs is mounted at `/jobs`.

**Tech Stack:** Rails 8.1, Hotwire, Solid Queue/Cache/Cable, SQLite, Minitest, Mission Control Jobs, importmap (default JS)

---

## File structure

| Path | Responsibility |
|------|----------------|
| `docs/superpowers/specs/2026-07-14-solid-activity-design.md` | Approved design (already present — preserve) |
| `app/models/user.rb` | Auth user; `has_many :posts, :comments` |
| `app/models/session.rb` | Rails 8 session model |
| `app/models/post.rb` | Activity post; status + summary; comments |
| `app/models/comment.rb` | Comment on a post |
| `app/jobs/enrich_post_job.rb` | Local summary heuristic → ready → Cable broadcast |
| `app/jobs/purge_stale_pending_posts_job.rb` | Destroy pending posts older than 15 minutes |
| `app/controllers/registrations_controller.rb` | Sign-up (not included in `authentication` generator) |
| `app/controllers/posts_controller.rb` | Create/destroy posts; Turbo Stream create response |
| `app/controllers/comments_controller.rb` | Create/destroy comments; broadcast append |
| `app/controllers/activity_controller.rb` | Authenticated feed index |
| `app/views/activity/index.html.erb` | Feed + `turbo_stream_from "activity"` + new-post form |
| `app/views/posts/_post.html.erb` | Status-aware partial (pending/ready/failed) + cache + callouts |
| `app/views/comments/_comment.html.erb` | Comment row |
| `config/recurring.yml` | Register purge job |
| `config/routes.rb` | Auth, activity, posts, comments, `/jobs` |
| `test/models/post_test.rb`, `comment_test.rb` | Validations/associations |
| `test/jobs/enrich_post_job_test.rb`, `purge_stale_pending_posts_job_test.rb` | Job behavior |
| `test/controllers/posts_controller_test.rb`, `comments_controller_test.rb` | Request coverage |
| `test/system/activity_feed_test.rb` | Sign in → create post → see ready item |

---

### Task 1: Scaffold Rails 8 app (preserve docs)

**Files:**
- Create: full Rails app under `/Users/mattpolito/Work/solid-activity`
- Preserve: `docs/superpowers/**`

- [ ] **Step 1: Generate the app with SQLite + tests (ignore `~/.railsrc`)**

```bash
cd /Users/mattpolito/Work/solid-activity
rails new . --force --database=sqlite3 --no-rc
```

Do **not** pass `--skip-solid` or `-T`. `--no-rc` is required because `~/.railsrc` forces PostgreSQL and `--skip-test-unit`.

Expected: Gemfile includes `rails ~> 8.1`, `solid_queue`, `solid_cache`, `solid_cable`; `test/` directory exists; `config/database.yml` has `primary`, `queue`, `cache`, `cable` SQLite entries; existing `docs/` remains.

- [ ] **Step 2: Verify Solid config files exist**

```bash
ls config/queue.yml config/recurring.yml config/cache.yml config/cable.yml db/queue_schema.rb db/cache_schema.rb db/cable_schema.rb
bin/rails about
```

Expected: files present; About shows Rails 8.x.

- [ ] **Step 3: Initialize git if missing and commit scaffold**

```bash
cd /Users/mattpolito/Work/solid-activity
git init
git add -A
git status
git commit -m "$(cat <<'EOF'
chore: scaffold Rails 8 app with Solid stack defaults

EOF
)"
```

---

### Task 2: Enable Solid Queue in development + prepare databases

**Files:**
- Modify: `config/environments/development.rb`
- Modify: `config/environments/test.rb` (use `:test` adapter for Active Job; keep solid cache/cable defaults where present)
- Modify: `Procfile.dev` or `bin/dev` if present — ensure `bin/jobs` runs alongside server

- [ ] **Step 1: Use Solid Queue in development**

In `config/environments/development.rb`, set:

```ruby
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```

(If `rails new` already added solid_queue only for production, mirror the production Active Job / Solid Queue lines into development.)

- [ ] **Step 2: Keep test jobs inline**

In `config/environments/test.rb` ensure:

```ruby
config.active_job.queue_adapter = :test
```

- [ ] **Step 3: Prepare all databases**

```bash
bin/rails db:prepare
```

Expected: `storage/development.sqlite3` plus queue/cache/cable DBs created without error.

- [ ] **Step 4: Commit**

```bash
git add config/environments/development.rb config/environments/test.rb
git commit -m "$(cat <<'EOF'
chore: run Solid Queue in development

EOF
)"
```

---

### Task 3: Authentication + registration

**Files:**
- Generate: Rails authentication (User, Session, SessionsController, PasswordsController, Authentication concern)
- Create: `app/controllers/registrations_controller.rb`
- Create: `app/views/registrations/new.html.erb`
- Modify: `app/models/user.rb` — add `has_many :posts`, `has_many :comments` later in Task 4/5; for now ensure password validations from generator
- Modify: `config/routes.rb`
- Test: `test/controllers/registrations_controller_test.rb`, `test/controllers/sessions_controller_test.rb` (generator may create some)

- [ ] **Step 1: Generate authentication**

```bash
bin/rails generate authentication
bin/rails db:migrate
```

- [ ] **Step 2: Write failing registration request test**

Create `test/controllers/registrations_controller_test.rb`:

```ruby
require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_registration_url
    assert_response :success
  end

  test "should register user and sign in" do
    assert_difference("User.count", 1) do
      post registration_url, params: {
        user: { email_address: "demo@example.com", password: "password123", password_confirmation: "password123" }
      }
    end

    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

```bash
bin/rails test test/controllers/registrations_controller_test.rb
```

Expected: FAIL (missing route/controller).

- [ ] **Step 4: Implement registration**

`config/routes.rb` (merge with generated auth routes):

```ruby
resource :registration, only: %i[new create]
resources :sessions, only: %i[new create destroy]
resources :passwords, param: :token

root "activity#index"
```

`app/controllers/registrations_controller.rb`:

```ruby
class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      start_new_session_for @user
      redirect_to root_path, notice: "Welcome!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def user_params
      params.require(:user).permit(:email_address, :password, :password_confirmation)
    end
end
```

`app/views/registrations/new.html.erb` — form with email + password + confirmation fields matching `User` attribute names from the generator (`email_address` in Rails 8).

Link to registration from `sessions/new`.

Adjust `allow_unauthenticated_access` / helper names to match whatever the generator put in `Authentication` concern (Rails 8.1 may use `allow_unauthenticated_access` and `start_new_session_for`).

- [ ] **Step 5: Stub ActivityController so root works**

```ruby
# app/controllers/activity_controller.rb
class ActivityController < ApplicationController
  def index
  end
end
```

```erb
<%# app/views/activity/index.html.erb %>
<p>Activity feed coming soon.</p>
```

- [ ] **Step 6: Run registration tests**

```bash
bin/rails test test/controllers/registrations_controller_test.rb
```

Expected: PASS. Fix attribute names if generator differs (`email` vs `email_address`).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: add Rails auth and user registration

EOF
)"
```

---

### Task 4: Post model

**Files:**
- Create: migration + `app/models/post.rb`
- Modify: `app/models/user.rb` — `has_many :posts, dependent: :destroy`
- Test: `test/models/post_test.rb`

- [ ] **Step 1: Write failing model tests**

`test/models/post_test.rb`:

```ruby
require "test_helper"

class PostTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "author@example.com", password: "password123", password_confirmation: "password123")
  end

  test "requires body" do
    post = Post.new(user: @user, body: "", status: :pending)
    assert_not post.valid?
    assert_includes post.errors[:body], "can't be blank"
  end

  test "defaults status to pending" do
    post = Post.create!(user: @user, body: "Hello feed")
    assert post.pending?
  end

  test "belongs to user" do
    post = Post.create!(user: @user, body: "Hello")
    assert_equal @user, post.user
  end
end
```

(Adjust `User.create!` attrs to match generator.)

- [ ] **Step 2: Run to verify fail**

```bash
bin/rails test test/models/post_test.rb
```

Expected: FAIL — `Post` missing.

- [ ] **Step 3: Generate model and implement**

```bash
bin/rails generate model Post user:references body:text summary:text status:string
```

Edit migration to:

```ruby
t.references :user, null: false, foreign_key: true
t.text :body, null: false
t.text :summary
t.string :status, null: false, default: "pending"
t.timestamps
```

Add index on `[:status, :created_at]` for the purge job.

`app/models/post.rb`:

```ruby
class Post < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :destroy

  enum :status, { pending: "pending", ready: "ready", failed: "failed" }, default: :pending

  validates :body, presence: true

  def enrich_summary!
    text = body.to_s.squish
    summary = text.length > 140 ? "#{text[0, 140]}…" : text
    update!(summary: summary, status: :ready)
  end
end
```

`User`:

```ruby
has_many :posts, dependent: :destroy
```

```bash
bin/rails db:migrate
```

- [ ] **Step 4: Run tests**

```bash
bin/rails test test/models/post_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: add Post model with pending/ready/failed status

EOF
)"
```

---

### Task 5: Comment model

**Files:**
- Create: migration + `app/models/comment.rb`
- Modify: `app/models/user.rb`, `app/models/post.rb`
- Test: `test/models/comment_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
require "test_helper"

class CommentTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "c@example.com", password: "password123", password_confirmation: "password123")
    @post = Post.create!(user: @user, body: "Parent post")
  end

  test "requires body" do
    comment = Comment.new(user: @user, post: @post, body: "")
    assert_not comment.valid?
  end

  test "belongs to post and user" do
    comment = Comment.create!(user: @user, post: @post, body: "Nice")
    assert_equal @post, comment.post
    assert_equal @user, comment.user
  end
end
```

- [ ] **Step 2: Run to verify fail**

```bash
bin/rails test test/models/comment_test.rb
```

- [ ] **Step 3: Generate and implement**

```bash
bin/rails generate model Comment user:references post:references body:text
bin/rails db:migrate
```

```ruby
class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :post, touch: true

  validates :body, presence: true
end
```

```ruby
# User
has_many :comments, dependent: :destroy
```

- [ ] **Step 4: Run tests + commit**

```bash
bin/rails test test/models/comment_test.rb
git add -A
git commit -m "$(cat <<'EOF'
feat: add Comment model touching parent post

EOF
)"
```

---

### Task 6: EnrichPostJob

**Files:**
- Create: `app/jobs/enrich_post_job.rb`
- Test: `test/jobs/enrich_post_job_test.rb`

- [ ] **Step 1: Write failing job tests**

```ruby
require "test_helper"

class EnrichPostJobTest < ActiveJob::TestCase
  setup do
    @user = User.create!(email_address: "j@example.com", password: "password123", password_confirmation: "password123")
    @post = Post.create!(user: @user, body: "a" * 200, status: :pending)
  end

  test "enriches summary and marks ready" do
    EnrichPostJob.perform_now(@post.id)
    @post.reload
    assert @post.ready?
    assert_equal 141, @post.summary.length # 140 chars + ellipsis
    assert @post.summary.end_with?("…")
  end

  test "marks failed when retries are exhausted via discard path" do
    post = @post
    EnrichPostJob.perform_now(post.id) # happy path above already covers success

    # Simulate discard callback contract:
    job = EnrichPostJob.new
    job.define_singleton_method(:arguments) { [post.id] }
    # Prefer testing the public method used by after_discard:
    EnrichPostJob.mark_failed!(post.id)
    assert post.reload.failed?
  end
end
```

Refine the failure test in Step 3 to call the same method `after_discard` uses — keep one public class method `mark_failed!(post_id)`.

- [ ] **Step 2: Run to verify fail**

```bash
bin/rails test test/jobs/enrich_post_job_test.rb
```

- [ ] **Step 3: Implement job**

```ruby
class EnrichPostJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 1.second, attempts: 3

  after_discard do |_job, _error|
    post_id = arguments.first
    mark_failed!(post_id)
  end

  def self.mark_failed!(post_id)
    post = Post.find_by(id: post_id)
    return unless post&.pending?

    post.update!(status: :failed)
    post.broadcast_replace_to "activity", target: ActionView::RecordIdentifier.dom_id(post), partial: "posts/post", locals: { post: post }
  end

  def perform(post_id)
    post = Post.find(post_id)
    return unless post.pending?

    post.enrich_summary!
    post.broadcast_replace_to "activity",
      target: ActionView::RecordIdentifier.dom_id(post),
      partial: "posts/post",
      locals: { post: post }
  end
end
```

Note: broadcasting from the job requires the `_post` partial to exist; create a minimal stub partial in this task if Task 7 is not done yet:

```erb
<%# app/views/posts/_post.html.erb %>
<%= tag.div id: dom_id(post) do %>
  <p><%= post.body %></p>
  <p><%= post.status %></p>
  <p><%= post.summary %></p>
<% end %>
```

- [ ] **Step 4: Fix failure test to match implementation**

```ruby
test "mark_failed! sets failed status" do
  EnrichPostJob.mark_failed!(@post.id)
  assert @post.reload.failed?
end
```

- [ ] **Step 5: Run tests + commit**

```bash
bin/rails test test/jobs/enrich_post_job_test.rb
git add -A
git commit -m "$(cat <<'EOF'
feat: add EnrichPostJob with summary heuristic and failure path

EOF
)"
```

---

### Task 7: PurgeStalePendingPostsJob + recurring schedule

**Files:**
- Create: `app/jobs/purge_stale_pending_posts_job.rb`
- Modify: `config/recurring.yml`
- Test: `test/jobs/purge_stale_pending_posts_job_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
require "test_helper"

class PurgeStalePendingPostsJobTest < ActiveJob::TestCase
  setup do
    @user = User.create!(email_address: "p@example.com", password: "password123", password_confirmation: "password123")
  end

  test "destroys pending posts older than 15 minutes" do
    stale = Post.create!(user: @user, body: "stale", status: :pending, created_at: 16.minutes.ago)
    fresh = Post.create!(user: @user, body: "fresh", status: :pending)
    ready = Post.create!(user: @user, body: "ready", status: :ready, created_at: 1.hour.ago)

    assert_difference("Post.count", -1) do
      PurgeStalePendingPostsJob.perform_now
    end

    assert_not Post.exists?(stale.id)
    assert Post.exists?(fresh.id)
    assert Post.exists?(ready.id)
  end
end
```

- [ ] **Step 2: Run to verify fail**

```bash
bin/rails test test/jobs/purge_stale_pending_posts_job_test.rb
```

- [ ] **Step 3: Implement job + recurring.yml**

```ruby
class PurgeStalePendingPostsJob < ApplicationJob
  queue_as :default

  def perform
    Post.pending.where("created_at < ?", 15.minutes.ago).find_each(&:destroy!)
  end
end
```

Append to `config/recurring.yml` (keep any existing clear-finished-jobs entry):

```yaml
purge_stale_pending_posts:
  class: PurgeStalePendingPostsJob
  queue: default
  schedule: every 5 minutes
```

Ensure development + production keys both include this task if the file is env-keyed.

- [ ] **Step 4: Run tests + commit**

```bash
bin/rails test test/jobs/purge_stale_pending_posts_job_test.rb
git add -A
git commit -m "$(cat <<'EOF'
feat: add recurring purge for stale pending posts

EOF
)"
```

---

### Task 8: Activity feed UI + post create (Queue + Cable path)

**Files:**
- Modify: `app/controllers/activity_controller.rb`, `app/controllers/posts_controller.rb`
- Modify: `app/views/activity/index.html.erb`, `app/views/posts/_post.html.erb`, `app/views/posts/_form.html.erb`
- Modify: `config/routes.rb`
- Create: `app/views/posts/create.turbo_stream.erb` (optional if using `respond_to`)
- Test: `test/controllers/posts_controller_test.rb`

- [ ] **Step 1: Write failing controller test**

```ruby
require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "poster@example.com", password: "password123", password_confirmation: "password123")
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "create enqueues enrich job and inserts pending post" do
    assert_enqueued_with(job: EnrichPostJob) do
      assert_difference("Post.count", 1) do
        post posts_url, params: { post: { body: "Live from Solid" } }
      end
    end

    created = Post.last
    assert created.pending?
    assert_redirected_to root_url # or assert turbo stream response if using streams
  end

  test "create rejects blank body" do
    assert_no_difference("Post.count") do
      post posts_url, params: { post: { body: "" } }
    end
    assert_response :unprocessable_entity
  end
end
```

Adjust session create params/path to match generated SessionsController.

- [ ] **Step 2: Run to verify fail**

```bash
bin/rails test test/controllers/posts_controller_test.rb
```

- [ ] **Step 3: Implement routes, controller, views**

Routes:

```ruby
resources :posts, only: %i[create destroy] do
  resources :comments, only: %i[create destroy]
end
```

```ruby
class ActivityController < ApplicationController
  def index
    @posts = Post.includes(:user, :comments).order(created_at: :desc)
    @post = Post.new
  end
end
```

```ruby
class PostsController < ApplicationController
  before_action :set_post, only: :destroy

  def create
    @post = Current.user.posts.new(post_params)
    @post.status = :pending

    if @post.save
      EnrichPostJob.perform_later(@post.id)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to root_path, notice: "Post submitted." }
      end
    else
      @posts = Post.includes(:user, :comments).order(created_at: :desc)
      render "activity/index", status: :unprocessable_entity
    end
  end

  def destroy
    if @post.user_id == Current.user.id
      @post.destroy!
      redirect_to root_path, notice: "Post deleted."
    else
      head :forbidden
    end
  end

  private
    def set_post
      @post = Post.find(params[:id])
    end

    def post_params
      params.require(:post).permit(:body)
    end
end
```

Use the generator’s current-user API (`Current.user` or `Current.session.user`) consistently.

`app/views/posts/create.turbo_stream.erb`:

```erb
<%= turbo_stream.prepend "activity_feed", partial: "posts/post", locals: { post: @post } %>
<%= turbo_stream.update "new_post_form", partial: "posts/form", locals: { post: Post.new } %>
```

`app/views/activity/index.html.erb`:

```erb
<%= turbo_stream_from "activity" %>

<header>
  <h1>Solid Activity</h1>
  <p>Showcase feed — Queue enriches, Cable streams, Cache serves repeats.</p>
  <%= link_to "Mission Control", "/jobs" %>
  <%= button_to "Sign out", session_path, method: :delete %>
</header>

<section id="new_post_form">
  <%= render "posts/form", post: @post %>
</section>

<div id="activity_feed">
  <%= render @posts %>
</div>
```

Upgrade `app/views/posts/_post.html.erb` with status branches + showcase callouts (caching added in Task 9):

```erb
<%= tag.article id: dom_id(post), class: "post post--#{post.status}" do %>
  <header>
    <strong><%= post.user.email_address %></strong>
    <span class="callout callout--cable">Solid Cable</span>
  </header>

  <% if post.pending? %>
    <p class="callout callout--queue">Processing via Solid Queue…</p>
    <p><%= post.body %></p>
  <% elsif post.failed? %>
    <p class="callout callout--queue">Enrichment failed (Solid Queue)</p>
    <p><%= post.body %></p>
  <% else %>
    <p class="summary"><%= post.summary %></p>
    <p><%= post.body %></p>
  <% end %>

  <% if post.user_id == Current.user&.id %>
    <%= button_to "Delete", post_path(post), method: :delete %>
  <% end %>

  <section id="<%= dom_id(post, :comments) %>">
    <%= render post.comments.includes(:user) if post.comments.loaded? || post.persisted? %>
  </section>

  <% if post.ready? %>
    <%= form_with model: [post, Comment.new], id: dom_id(post, :comment_form) do |f| %>
      <%= f.text_area :body, required: true %>
      <%= f.submit "Comment" %>
    <% end %>
  <% end %>
<% end %>
```

- [ ] **Step 4: Run controller tests**

```bash
bin/rails test test/controllers/posts_controller_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: activity feed with pending posts and EnrichPostJob enqueue

EOF
)"
```

---

### Task 9: Solid Cache on feed partials + Cache callout

**Files:**
- Modify: `app/views/posts/_post.html.erb`
- Modify: `config/environments/development.rb` — ensure `config.action_controller.enable_fragment_cache_logging = true` (optional, aids demo)
- Ensure production/development cache store is `:solid_cache_store` (Rails 8 default after solid install)

- [ ] **Step 1: Wrap ready posts in Russian-doll fragment cache**

```erb
<% cache post do %>
  <%= tag.article id: dom_id(post), class: "post post--#{post.status}" do %>
    <header>
      <strong><%= post.user.email_address %></strong>
      <span class="callout callout--cable">Solid Cable</span>
      <% if post.ready? %>
        <span class="callout callout--cache">Solid Cache</span>
      <% end %>
    </header>
    <%# ... same body as Task 8 ... %>
  <% end %>
<% end %>
```

Only cache the inner content for `ready?` posts if pending rows must stay dynamic — preferred pattern:

```erb
<%= tag.article id: dom_id(post), class: "post post--#{post.status}" do %>
  <% if post.ready? %>
    <% cache post do %>
      <%= render "posts/post_ready", post: post %>
    <% end %>
  <% else %>
    <%= render "posts/post_pending_or_failed", post: post %>
  <% end %>
<% end %>
```

Split partials accordingly so `dom_id` wrappers stay outside cache for Cable replace targets.

- [ ] **Step 2: Manually verify cache store**

```bash
bin/rails runner 'puts Rails.cache.class.name'
```

Expected: includes `SolidCache` (in development once configured). If development still uses `MemoryStore`, set:

```ruby
config.cache_store = :solid_cache_store
```

in `development.rb`.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: fragment-cache ready posts via Solid Cache

EOF
)"
```

---

### Task 10: Comments with Cable broadcast

**Files:**
- Create: `app/controllers/comments_controller.rb`
- Create: `app/views/comments/_comment.html.erb`, `create.turbo_stream.erb`
- Test: `test/controllers/comments_controller_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "commenter@example.com", password: "password123", password_confirmation: "password123")
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @post = Post.create!(user: @user, body: "Ready post", status: :ready, summary: "Ready post")
  end

  test "create adds comment" do
    assert_difference("Comment.count", 1) do
      post post_comments_url(@post), params: { comment: { body: "Agreed" } }
    end
  end
end
```

- [ ] **Step 2: Implement controller**

```ruby
class CommentsController < ApplicationController
  before_action :set_post

  def create
    @comment = @post.comments.new(comment_params)
    @comment.user = Current.user

    if @comment.save
      @comment.broadcast_append_to "activity",
        target: ActionView::RecordIdentifier.dom_id(@post, :comments),
        partial: "comments/comment",
        locals: { comment: @comment }
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to root_path }
      end
    else
      redirect_to root_path, alert: "Comment can't be blank."
    end
  end

  def destroy
    @comment = @post.comments.find(params[:id])
    if @comment.user_id == Current.user.id
      @comment.destroy!
    end
    redirect_to root_path
  end

  private
    def set_post
      @post = Post.find(params[:post_id])
    end

    def comment_params
      params.require(:comment).permit(:body)
    end
end
```

- [ ] **Step 3: Run tests + commit**

```bash
bin/rails test test/controllers/comments_controller_test.rb
git add -A
git commit -m "$(cat <<'EOF'
feat: comments with Turbo Stream append over Solid Cable

EOF
)"
```

---

### Task 11: Mission Control Jobs

**Files:**
- Modify: `Gemfile`
- Modify: `config/routes.rb`
- Modify: `config/application.rb` or an initializer for HTTP basic (dev-friendly)

- [ ] **Step 1: Add gem and install**

```bash
bundle add mission_control-jobs
```

- [ ] **Step 2: Mount engine**

```ruby
# config/routes.rb
mount MissionControl::Jobs::Engine, at: "/jobs"
```

In `config/application.rb` (or `config/initializers/mission_control_jobs.rb`):

```ruby
config.mission_control.jobs.http_basic_auth_user = ENV.fetch("JOBS_USER", "admin")
config.mission_control.jobs.http_basic_auth_password = ENV.fetch("JOBS_PASSWORD", "solid")
```

(Check gem README for exact config keys for v1.1 — adjust if names differ.)

- [ ] **Step 3: Smoke check**

```bash
bin/rails runner 'puts MissionControl::Jobs::Engine'
```

Expected: constant loads. Manual: visit `/jobs` with basic auth.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: mount Mission Control Jobs at /jobs

EOF
)"
```

---

### Task 12: System test for the happy path

**Files:**
- Create: `test/system/activity_feed_test.rb`
- Modify: `test/application_system_test_case.rb` if needed (Selenium/Cuprite defaults)

- [ ] **Step 1: Write system test**

```ruby
require "application_system_test_case"

class ActivityFeedTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(email_address: "sys@example.com", password: "password123", password_confirmation: "password123")
  end

  test "sign in create post and see enriched feed item" do
    visit new_session_url
    fill_in "email_address", with: @user.email_address
    fill_in "password", with: "password123"
    click_button "Sign in"

    fill_in "post_body", with: "System test post for Solid"
    click_button "Post"

    perform_enqueued_jobs

    visit root_url
    assert_text "System test post for Solid"
    assert_text "Solid Cache" # callout on ready post
  end
end
```

Field labels/names must match forms. Because development uses Solid Queue but tests use `:test` adapter, `perform_enqueued_jobs` is correct in system tests when Active Job adapter is `:test`.

- [ ] **Step 2: Run system test**

```bash
bin/rails test:system test/system/activity_feed_test.rb
```

Expected: PASS (may need `brew install chromedriver` / Playwright per Rails 8 defaults — fix driver setup if failing).

- [ ] **Step 3: Run full suite**

```bash
bin/rails test
bin/rails test:system
```

Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
test: system coverage for sign-in and enriched feed post

EOF
)"
```

---

### Task 13: README + runbook

**Files:**
- Create/overwrite: `README.md`

- [ ] **Step 1: Document how to run the demo**

Include:

```markdown
# solid-activity

Rails 8 demo: authenticated activity feed showcasing Solid Queue, Solid Cache, and Solid Cable.

## Setup
bundle install
bin/rails db:prepare

## Run
bin/dev   # or: bin/rails server + bin/jobs in a second terminal

Open http://localhost:3000
Mission Control: http://localhost:3000/jobs (admin / solid by default)

## What to notice
- New posts appear as pending (Queue callout), then flip to ready over Cable
- Ready posts show a Cache callout and are fragment-cached
- Recurring purge removes pending posts older than 15 minutes
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs: add solid-activity runbook

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Rails 8 + Solid + SQLite scaffold | 1–2 |
| Auth + sign-up | 3 |
| Post/Comment models | 4–5 |
| EnrichPostJob local heuristic + broadcast | 6, 8 |
| Failed status after discard | 6 |
| Recurring purge 15 minutes | 7 |
| Feed Turbo Streams / Cable | 8, 10 |
| Fragment cache + callouts | 8–9 |
| Mission Control `/jobs` | 11 |
| Minitest model/request/job/system | 4–7, 8, 10, 12 |
| Out of scope respected (no RSpec/Redis/Postgres) | All |

---

## Self-review notes

- No TBD placeholders; enrichment is a local 140-char heuristic.
- `Current.user` / session helpers must be aligned with the auth generator during Task 3 — adjust names once, reuse everywhere.
- Use `--no-rc` on `rails new` so `~/.railsrc` (Postgres + skip tests) does not fight the spec.
