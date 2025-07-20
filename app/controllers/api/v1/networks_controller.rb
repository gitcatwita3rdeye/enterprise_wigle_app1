class Api::V1::NetworksController < Api::V1::BaseController
  def index
    @networks = WifiNetwork.includes(:network_observations)
    
    # Apply filters
    @networks = apply_filters(@networks)
    
    # Pagination
    @networks = @networks.page(params[:page]).per(params[:per_page] || 100)
    
    # Get statistics
    statistics = calculate_statistics(@networks.unscoped)
    
    render json: {
      success: true,
      networks: @networks.map { |network| serialize_network(network) },
      statistics: statistics,
      pagination: pagination_metadata(@networks),
      timestamp: Time.current.iso8601
    }
  end
  
  def show
    @network = WifiNetwork.friendly.find(params[:id])
    @observations = @network.network_observations
                            .includes(:wardrive_session)
                            .order(timestamp: :desc)
                            .limit(100)
    
    render json: {
      success: true,
      network: serialize_network_detail(@network),
      recent_observations: @observations.map { |obs| serialize_observation(obs) },
      timestamp: Time.current.iso8601
    }
  rescue ActiveRecord::RecordNotFound
    render_error("Network not found", :not_found)
  end
  
  def search
    query = params[:q]&.strip
    return render_error("Search query required") if query.blank?
    
    @networks = WifiNetwork.includes(:network_observations)
    
    # Search by SSID, BSSID, or vendor
    @networks = @networks.where(
      "ssid ILIKE ? OR bssid ILIKE ? OR vendor ILIKE ?", 
      "%#{query}%", "%#{query}%", "%#{query}%"
    )
    
    # Apply additional filters
    @networks = apply_filters(@networks)
    
    # Pagination
    @networks = @networks.page(params[:page]).per(params[:per_page] || 50)
    
    render json: {
      success: true,
      query: query,
      networks: @networks.map { |network| serialize_network(network) },
      pagination: pagination_metadata(@networks),
      timestamp: Time.current.iso8601
    }
  end
  
  def nearby
    lat = params[:latitude]&.to_f
    lng = params[:longitude]&.to_f
    radius = (params[:radius] || 1.0).to_f # km
    
    return render_error("Latitude and longitude required") unless lat && lng
    
    @networks = WifiNetwork.within_radius(lat, lng, radius)
                           .includes(:network_observations)
                           .limit(params[:limit] || 200)
    
    render json: {
      success: true,
      center: { latitude: lat, longitude: lng },
      radius_km: radius,
      networks: @networks.map { |network| serialize_network(network) },
      count: @networks.count,
      timestamp: Time.current.iso8601
    }
  end
  
  def heatmap_data
    bounds = extract_bounds
    return render_error("Geographic bounds required") unless bounds
    
    # Get networks within bounds
    @networks = WifiNetwork.where(
      latitude: bounds[:south]..bounds[:north],
      longitude: bounds[:west]..bounds[:east]
    ).includes(:network_observations)
    
    # Apply security filter if specified
    if params[:security_filter].present?
      @networks = filter_by_security(@networks, params[:security_filter])
    end
    
    # Generate heatmap data points
    heatmap_points = @networks.map do |network|
      intensity = calculate_signal_intensity(network)
      [
        network.latitude,
        network.longitude,
        intensity
      ]
    end
    
    render json: {
      success: true,
      bounds: bounds,
      heatmap_data: heatmap_points,
      total_networks: heatmap_points.count,
      timestamp: Time.current.iso8601
    }
  end
  
  def export
    format = params[:format] || 'geojson'
    @networks = WifiNetwork.includes(:network_observations)
    
    # Apply filters
    @networks = apply_filters(@networks)
    
    case format.downcase
    when 'geojson'
      render json: export_geojson(@networks)
    when 'kml'
      render xml: export_kml(@networks), content_type: 'application/vnd.google-earth.kml+xml'
    when 'csv'
      send_data export_csv(@networks), 
                filename: "networks_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
                type: 'text/csv'
    else
      render_error("Unsupported export format. Use: geojson, kml, or csv")
    end
  end
  
  private
  
  def apply_filters(networks)
    # Security filter
    if params[:security].present?
      networks = filter_by_security(networks, params[:security])
    end
    
    # Signal strength filter
    if params[:min_signal].present?
      networks = networks.by_signal_strength(params[:min_signal].to_i)
    end
    
    # Time range filter
    if params[:since].present?
      since_time = Time.parse(params[:since]) rescue 1.week.ago
      networks = networks.where('last_seen > ?', since_time)
    end
    
    # Geographic bounds filter
    if bounds = extract_bounds
      networks = networks.where(
        latitude: bounds[:south]..bounds[:north],
        longitude: bounds[:west]..bounds[:east]
      )
    end
    
    # Vendor filter
    if params[:vendor].present?
      networks = networks.where('vendor ILIKE ?', "%#{params[:vendor]}%")
    end
    
    # Channel filter
    if params[:channel].present?
      networks = networks.where(channel: params[:channel])
    end
    
    networks
  end
  
  def filter_by_security(networks, security_type)
    case security_type.downcase
    when 'open'
      networks.open_networks
    when 'secured'
      networks.secured_networks
    when 'wep'
      networks.where("encryption ILIKE '%wep%'")
    when 'wpa'
      networks.where("encryption ILIKE '%wpa%' AND encryption NOT ILIKE '%wpa3%'")
    when 'wpa3'
      networks.where("encryption ILIKE '%wpa3%'")
    else
      networks
    end
  end
  
  def extract_bounds
    return nil unless params[:bounds].present?
    
    if params[:bounds].is_a?(String)
      # Parse "south,west,north,east" format
      coords = params[:bounds].split(',').map(&:to_f)
      return nil unless coords.length == 4
      
      {
        south: coords[0],
        west: coords[1], 
        north: coords[2],
        east: coords[3]
      }
    elsif params[:bounds].is_a?(Hash)
      {
        south: params[:bounds][:south]&.to_f,
        west: params[:bounds][:west]&.to_f,
        north: params[:bounds][:north]&.to_f,
        east: params[:bounds][:east]&.to_f
      }
    end
  end
  
  def calculate_statistics(networks)
    {
      total_networks: networks.count,
      open_networks: networks.open_networks.count,
      secured_networks: networks.secured_networks.count,
      avg_signal_strength: networks.average(:signal_strength)&.round(1),
      total_observations: NetworkObservation.joins(:wifi_network).merge(networks).count,
      unique_vendors: networks.distinct.count(:vendor),
      coverage_area: calculate_total_coverage_area(networks),
      last_updated: networks.maximum(:last_seen)
    }
  end
  
  def calculate_total_coverage_area(networks)
    # Simple bounding box area calculation
    return 0 if networks.empty?
    
    bounds = networks.select(:latitude, :longitude).map do |n|
      [n.latitude, n.longitude]
    end.compact
    
    return 0 if bounds.empty?
    
    lats = bounds.map(&:first)
    lngs = bounds.map(&:last)
    
    lat_range = lats.max - lats.min
    lng_range = lngs.max - lngs.min
    
    # Rough area calculation in km²
    (lat_range * 111.32) * (lng_range * 111.32 * Math.cos(lats.sum / lats.size * Math::PI / 180))
  end
  
  def calculate_signal_intensity(network)
    # Convert signal strength to intensity (0.0 to 1.0)
    signal = network.signal_strength || -80
    # Map -100 to -30 dBm to 0.0 to 1.0
    intensity = [(signal + 100) / 70.0, 0.0].max
    [intensity, 1.0].min
  end
  
  def serialize_network(network)
    {
      id: network.id,
      slug: network.slug,
      ssid: network.ssid,
      bssid: network.bssid,
      encryption: network.encryption,
      security_level: network.security_level,
      channel: network.channel,
      frequency: network.channel_frequency,
      signal_strength: network.signal_strength,
      vendor: network.vendor,
      latitude: network.latitude,
      longitude: network.longitude,
      first_seen: network.first_seen&.iso8601,
      last_seen: network.last_seen&.iso8601,
      observation_count: network.observation_count || 0,
      risk_level: assess_risk_level(network)
    }
  end
  
  def serialize_network_detail(network)
    serialize_network(network).merge({
      capabilities: network.capabilities,
      altitude: network.altitude,
      accuracy: network.accuracy,
      sessions: network.wardrive_sessions.count,
      geographic_info: {
        coordinates: network.coordinates,
        estimated_range: estimate_coverage_range(network)
      }
    })
  end
  
  def serialize_observation(observation)
    {
      id: observation.id,
      latitude: observation.latitude,
      longitude: observation.longitude,
      signal_strength: observation.signal_strength,
      signal_quality: observation.signal_quality,
      timestamp: observation.timestamp.iso8601,
      altitude: observation.altitude,
      gps_accuracy: observation.gps_accuracy,
      session: {
        id: observation.wardrive_session.id,
        name: observation.wardrive_session.name,
        slug: observation.wardrive_session.slug
      }
    }
  end
  
  def assess_risk_level(network)
    case network.encryption&.downcase
    when 'open', 'none', ''
      'high'
    when /wep/
      'high'
    when /wpa$/
      'medium'
    when /wpa2/
      'low'
    when /wpa3/
      'very_low'
    else
      'unknown'
    end
  end
  
  def estimate_coverage_range(network)
    # Estimate coverage range based on signal strength observations
    observations = network.network_observations.where.not(signal_strength: nil)
    return 50 if observations.empty? # Default 50m
    
    avg_signal = observations.average(:signal_strength)
    return 50 unless avg_signal
    
    # Rough estimation: stronger signal = larger coverage
    case avg_signal.to_i
    when -30..-1
      200  # Very strong
    when -50..-31
      100  # Strong
    when -70..-51
      50   # Medium
    when -85..-71
      25   # Weak
    else
      10   # Very weak
    end
  end
  
  def export_geojson(networks)
    features = networks.map do |network|
      {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [network.longitude, network.latitude]
        },
        properties: serialize_network(network)
      }
    end
    
    {
      type: "FeatureCollection",
      features: features,
      metadata: {
        generated_at: Time.current.iso8601,
        total_features: features.count,
        generator: "WigleViz Enterprise"
      }
    }
  end
  
  def export_kml(networks)
    # KML export implementation would go here
    # For brevity, returning a placeholder
    "<kml><!-- KML export not implemented yet --></kml>"
  end
  
  def export_csv(networks)
    CSV.generate(headers: true) do |csv|
      csv << %w[ssid bssid encryption channel frequency signal_strength vendor latitude longitude first_seen last_seen observation_count]
      
      networks.each do |network|
        csv << [
          network.ssid,
          network.bssid,
          network.encryption,
          network.channel,
          network.channel_frequency,
          network.signal_strength,
          network.vendor,
          network.latitude,
          network.longitude,
          network.first_seen&.iso8601,
          network.last_seen&.iso8601,
          network.observation_count
        ]
      end
    end
  end
end
