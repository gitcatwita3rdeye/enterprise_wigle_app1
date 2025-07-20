class NetworkObservation < ApplicationRecord
  belongs_to :wifi_network
  belongs_to :wardrive_session
  
  # Validations
  validates :latitude, :longitude, presence: true, numericality: true
  validates :timestamp, presence: true
  validates :signal_strength, numericality: { greater_than: -100, less_than: 0 }
  
  # Scopes
  scope :strong_signal, -> { where('signal_strength > ?', -60) }
  scope :weak_signal, -> { where('signal_strength < ?', -80) }
  scope :recent, -> { where('timestamp > ?', 1.hour.ago) }
  scope :by_timeframe, ->(start_time, end_time) { where(timestamp: start_time..end_time) }
  scope :within_area, ->(lat, lng, radius_km) {
    where(
      "(6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))) < ?",
      lat, lng, lat, radius_km
    )
  }
  
  # Geocoding
  geocoded_by :latitude, :longitude
  
  def coordinates
    [latitude, longitude]
  end
  
  def signal_quality
    case signal_strength
    when -30..-1
      'Excellent'
    when -50..-31
      'Good'
    when -70..-51
      'Fair'
    when -85..-71
      'Weak'
    else
      'Very Weak'
    end
  end
  
  def estimated_range_meters
    # Rough estimation based on signal strength
    case signal_strength
    when -30..-1
      5
    when -50..-31
      20
    when -70..-51
      50
    when -85..-71
      100
    else
      200
    end
  end
end
