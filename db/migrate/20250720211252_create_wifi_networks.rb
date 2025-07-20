class CreateWifiNetworks < ActiveRecord::Migration[8.0]
  def change
    create_table :wifi_networks do |t|
      t.string :ssid
      t.string :bssid
      t.string :encryption
      t.integer :frequency
      t.integer :channel
      t.integer :signal_strength
      t.decimal :latitude
      t.decimal :longitude
      t.decimal :altitude
      t.decimal :accuracy
      t.datetime :timestamp
      t.string :vendor
      t.text :capabilities
      t.datetime :first_seen
      t.datetime :last_seen
      t.integer :observation_count

      t.timestamps
    end
  end
end
