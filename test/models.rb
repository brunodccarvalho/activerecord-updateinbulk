# frozen_string_literal: true

class Author < ActiveRecord::Base
  has_many :posts
  has_many :books
end

class Book < ActiveRecord::Base
  belongs_to :author

  alias_attribute :title, :name

  enum :status, [:proposed, :written, :published]
  enum :last_read, { unread: 0, reading: 2, read: 3, forgotten: nil }
  enum :language, [:english, :spanish, :french], prefix: :in
  enum :author_visibility, [:visible, :invisible], prefix: true
  enum :font_size, [:small, :medium, :large], prefix: :with, suffix: true
  enum :difficulty, [:easy, :medium, :hard], suffix: :to_read
  enum :cover, { hard: "hard", soft: "soft" }
  enum :boolean_status, { enabled: true, disabled: false }
end

class Car < ActiveRecord::Base
  self.table_name = "vehicles"
  def full_name
    "#{make} #{model}"
  end
end

class Category < ActiveRecord::Base
end

class SpecialCategory < Category
end

class Post < ActiveRecord::Base; end

class Comment < ActiveRecord::Base
  belongs_to :post, counter_cache: true
  belongs_to :author,   polymorphic: true

  has_many :children, class_name: "Comment", inverse_of: :parent
  belongs_to :parent, class_name: "Comment", counter_cache: :children_count, inverse_of: :children
end

class SpecialComment < Comment
  has_one :author, through: :post
  default_scope { where(deleted_at: nil) }
end

class Pet < ActiveRecord::Base
  self.primary_key = :pet_id
  has_many :toys
end

class Toy < ActiveRecord::Base
  self.primary_key = :toy_id
  belongs_to :pet
end

class Post < ActiveRecord::Base
  alias_attribute :text, :body

  scope :most_commented, lambda { |comments_count|
    joins(:comments)
    .group("posts.id")
    .having("count(comments.id) >= ?", comments_count)
  }

  belongs_to :author

  has_one :first_comment, -> { order("id ASC") }, class_name: "Comment"
  has_one :last_comment, -> { order("id desc") }, class_name: "Comment"

  has_many :comments
end

class SpecialPost < Post; end

class User < ActiveRecord::Base
end
