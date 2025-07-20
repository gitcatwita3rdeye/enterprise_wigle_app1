class WifiNetwork < ApplicationRecord
  extend FriendlyId
  friendly_id :ssid, use: :slugged
  
  has_many :network_observations, dependent: :destroy
  has_many :wardrive_sessions, through: :network_observations
  
  # Geocoding
  geocoded_by :coordinates
  
  # Validations
  validates :bssid, presence: true, uniqueness: true
  validates :ssid, presence: true
  validates :latitude, :longitude, presence: true, numericality: true
  
  # Scopes
  scope :open_networks, -> { where(encryption: ['Open', 'None', '']) }
  scope :secured_networks, -> { where.not(encryption: ['Open', 'None', '']) }
  scope :recent, -> { where('first_seen > ?', 30.days.ago) }
  scope :by_signal_strength, ->(min_strength) { where('signal_strength > ?', min_strength) }
  scope :within_radius, ->(lat, lng, radius_km) {
    where(
      "(6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))) < ?",
      lat, lng, lat, radius_km
    )
  }
  
  # Methods
  def coordinates
    [latitude, longitude]
  end
  
  def security_level
    case encryption&.downcase
    when 'open', 'none', ''
      'Open'
    when /wep/
      'Low (WEP)'
    when /wpa$/
      'Medium (WPA)'
    when /wpa2/
      'High (WPA2)'
    when /wpa3/
      'Very High (WPA3)'
    else
      'Unknown'
    end
  end
  
  def channel_frequency
    return nil unless channel
    
    # 2.4GHz channels
    if channel <= 14
      2412 + (channel - 1) * 5
    # 5GHz channels
    elsif channel >= 36
      5000 + channel * 5
    else
      frequency
    end
  end
  
  def distance_from(lat, lng)
    return nil unless latitude && longitude
    
    # Haversine formula
    rad_per_deg = Math::PI / 180
    rkm = 6371
    rm = rkm * 1000
    
    dlat_rad = (latitude - lat) * rad_per_deg
    dlon_rad = (longitude - lng) * rad_per_deg
    
    lat1_rad, lat2_rad = lat * rad_per_deg, latitude * rad_per_deg
    
    a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    
    rm * c
  end
  
  def self.ransackable_attributes(auth_object = nil)
    %w[ssid bssid encryption channel signal_strength latitude longitude vendor capabilities first_seen last_seen]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[network_observations wardrive_sessions]
  end
end
