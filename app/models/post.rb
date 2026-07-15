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
