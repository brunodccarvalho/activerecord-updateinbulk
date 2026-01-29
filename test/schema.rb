# frozen_string_literal: true

ActiveRecord::Schema.define do
  unsigned = if ["mysql2", "trilogy"].include?(TestSupport::DatabaseConfig.adapter)
    { unsigned: true }
  else
    {}
  end

  create_table :users, force: true do |t|
    t.string :name
    t.string :settings, null: true, limit: 1024
    t.json :preferences
    t.json :notifications
  end

  create_table :authors, force: true do |t|
    t.string :name, null: false
  end

  create_table :books, id: :integer, force: true do |t|
    t.references :author
    t.string :format
    t.integer :pages, null: false, **unsigned, default: 0
    t.column :name, :string, limit: 48
    t.column :status, :integer, default: 0
    t.column :last_read, :integer, default: 0
    t.column :language, :integer, default: 0
    t.column :author_visibility, :integer, default: 0
    t.column :font_size, :integer, default: 0
    t.column :difficulty, :integer, default: 0
    t.column :cover, :string, default: "hard"
    t.datetime :published_on
    t.boolean :boolean_status
    t.index [:author_id, :name], unique: true

    t.datetime :created_at
    t.datetime :updated_at
    t.date :updated_on

    if TestSupport::DatabaseConfig.adapter == "sqlite3"
      t.check_constraint "length(name) <= 48", name: "books_name_length"
    end
  end

  create_table :categories, force: true do |t|
    t.string :name, null: false
    t.string :type, null: false # sti column
  end

  create_table :vehicles, force: true, primary_key: [:make, :model] do |t|
    t.string :make, null: false
    t.string :model, null: false
    t.integer :year, default: 0
  end

  create_table :comments, force: true do |t|
    t.integer :post_id, null: false
    t.text    :body, null: false
    t.string  :type
    t.integer :parent_id
    t.references :author, polymorphic: true
    t.datetime :updated_at
    t.datetime :deleted_at
    t.integer :company
  end

  create_table :posts, force: true do |t|
    t.references :author
    t.string :title, null: false
    t.text    :body, null: false
    t.string  :type
  end

  create_table :pets, primary_key: :pet_id, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :toys, primary_key: :toy_id, force: true do |t|
    t.string :name
    t.integer :pet_id, :integer
    t.timestamps null: false
  end

  create_table :type_varieties, force: true do |t|
    t.string  :col_string
    t.string  :col_varchar, limit: 16
    t.column  :col_char, :string, limit: 16
    t.text    :col_text

    t.integer :col_integer
    t.integer :col_smallint, limit: 2
    t.bigint  :col_bigint

    t.float   :col_float
    t.decimal :col_decimal, precision: 10, scale: 2

    t.date     :col_date
    t.datetime :col_datetime
    t.time     :col_time

    t.boolean :col_boolean
  end

  create_table :product_stocks, id: false, force: true do |t|
    t.string :name, null: false, limit: 24, primary_key: true
    t.integer :quantity, null: false, default: 0
    t.check_constraint "quantity >= 0", name: "quantity_non_negative"
    t.index :name, unique: true
  end
end
