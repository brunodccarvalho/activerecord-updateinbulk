# frozen_string_literal: true

class Author < ActiveRecord::Base
  has_many :books
end

class Book < ActiveRecord::Base
  alias_attribute :title, :name

  enum :status, [:proposed, :written, :published]
  enum :last_read, { unread: 0, reading: 2, read: 3, forgotten: nil }
  enum :language, [:english, :spanish, :french], prefix: :in
  enum :author_visibility, [:visible, :invisible], prefix: true
  enum :font_size, [:small, :medium, :large], prefix: :with, suffix: true
  enum :difficulty, [:easy, :medium, :hard], suffix: :to_read
  enum :cover, { hard: "hard", soft: "soft" }
  enum :boolean_status, { enabled: true, disabled: false }

  belongs_to :author
end

class Car < ActiveRecord::Base
  self.table_name = "vehicles"
  def full_name
    "#{make} #{model}"
  end
end

class Category < ActiveRecord::Base; end

class SpecialCategory < Category; end

class Post < ActiveRecord::Base; end

class Comment < ActiveRecord::Base; end

class SpecialComment < Comment
  default_scope { where(deleted_at: nil) }
end

class SubSpecialComment < SpecialComment; end

class VerySpecialComment < SpecialComment; end

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
  has_many :comments
end

class SpecialPost < Post; end

class User < ActiveRecord::Base; end

class ProductStock < ActiveRecord::Base; end

class TypeVariety < ActiveRecord::Base
  self.record_timestamps = false
end
