class AddSlugToWifiNetworks < ActiveRecord::Migration[8.0]
  def change
    add_column :wifi_networks, :slug, :string
    add_index :wifi_networks, :slug
  end
end
