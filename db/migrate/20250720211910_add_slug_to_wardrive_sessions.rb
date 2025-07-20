class AddSlugToWardriveSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :wardrive_sessions, :slug, :string
    add_index :wardrive_sessions, :slug
  end
end
