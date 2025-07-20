class CreateNetworkObservations < ActiveRecord::Migration[8.0]
  def change
    create_table :network_observations do |t|
      t.references :wifi_network, null: false, foreign_key: true
      t.references :wardrive_session, null: false, foreign_key: true
      t.decimal :latitude
      t.decimal :longitude
      t.decimal :altitude
      t.integer :signal_strength
      t.datetime :timestamp
      t.decimal :gps_accuracy

      t.timestamps
    end
  end
end
