class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.text :summary
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :posts, [:status, :created_at]
  end
end
