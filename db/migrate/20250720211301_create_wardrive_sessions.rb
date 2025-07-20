class CreateWardriveSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :wardrive_sessions do |t|
      t.string :name
      t.text :description
      t.datetime :start_time
      t.datetime :end_time
      t.string :user_name
      t.text :device_info
      t.integer :total_networks
      t.integer :unique_networks
      t.decimal :distance_covered
      t.string :file_format
      t.string :status

      t.timestamps
    end
  end
end
