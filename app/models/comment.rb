class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :post, touch: true

  validates :body, presence: true
end
