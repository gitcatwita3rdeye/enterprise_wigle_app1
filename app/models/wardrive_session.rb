class WardriveSession < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged
  
  has_many :network_observations, dependent: :destroy
  has_many :wifi_networks, through: :network_observations
  has_one_attached :data_file
  
  # Validations
  validates :name, presence: true
  validates :start_time, presence: true
  validates :file_format, inclusion: { in: %w[csv kml kismet magic8ball] }
  validates :status, inclusion: { in: %w[pending processing completed failed] }
  
  # Scopes
  scope :completed, -> { where(status: 'completed') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_format, ->(format) { where(file_format: format) }
  
  # Callbacks
  before_create :set_defaults
  after_update :calculate_statistics, if: :saved_change_to_status?
  
  def duration
    return nil unless start_time && end_time
    end_time - start_time
  end
  
  def duration_formatted
    return 'Ongoing' unless duration
    
    hours = (duration / 1.hour).to_i
    minutes = ((duration % 1.hour) / 1.minute).to_i
    seconds = (duration % 1.minute).to_i
    
    if hours > 0
      "#{hours}h #{minutes}m #{seconds}s"
    elsif minutes > 0
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end
  
  def coverage_area
    return 0 unless network_observations.exists?
    
    # Calculate bounding box area
    observations = network_observations.select(:latitude, :longitude)
    lats = observations.map(&:latitude).compact
    lngs = observations.map(&:longitude).compact
    
    return 0 if lats.empty? || lngs.empty?
    
    lat_range = lats.max - lats.min
    lng_range = lngs.max - lngs.min
    
    # Rough area calculation in km²
    (lat_range * 111.32) * (lng_range * 111.32 * Math.cos(lats.sum / lats.size * Math::PI / 180))
  end
  
  def processing?
    status == 'processing'
  end
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  private
  
  def set_defaults
    self.status ||= 'pending'
    self.start_time ||= Time.current
  end
  
  def calculate_statistics
    return unless status == 'completed'
    
    self.total_networks = network_observations.count
    self.unique_networks = wifi_networks.distinct.count
    self.end_time = Time.current if end_time.nil?
    
    # Calculate distance covered (rough estimation)
    observations = network_observations.order(:timestamp).select(:latitude, :longitude)
    if observations.count > 1
      total_distance = 0
      observations.each_cons(2) do |obs1, obs2|
        if obs1.latitude && obs1.longitude && obs2.latitude && obs2.longitude
          total_distance += calculate_distance(obs1.latitude, obs1.longitude, obs2.latitude, obs2.longitude)
        end
      end
      self.distance_covered = total_distance
    end
    
    save if changed?
  end
  
  def calculate_distance(lat1, lng1, lat2, lng2)
    rad_per_deg = Math::PI / 180
    rkm = 6371
    
    dlat_rad = (lat2 - lat1) * rad_per_deg
    dlon_rad = (lng2 - lng1) * rad_per_deg
    
    lat1_rad = lat1 * rad_per_deg
    lat2_rad = lat2 * rad_per_deg
    
    a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    
    rkm * c
  end
end
