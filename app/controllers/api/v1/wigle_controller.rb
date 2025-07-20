class Api::V1::WigleController < Api::V1::BaseController
  def sync
    bounds = extract_bounds_from_params
    return render_error("Geographic bounds required") unless bounds
    
    # Queue background sync job
    WigleSyncJob.perform_later(bounds, sync_options)
    
    render_success({
      message: "WiGLE sync started",
      bounds: bounds,
      estimated_completion: 5.minutes.from_now
    })
  end
  
  def search_networks
    bounds = extract_bounds_from_params
    return render_error("Geographic bounds required") unless bounds
    
    wigle_service = WigleApiService.new
    results = wigle_service.search_networks(bounds, search_options)
    
    if results[:success]
      render_success({
        networks: results[:networks],
        result_count: results[:result_count],
        total_results: results[:total_results],
        bounds: bounds
      })
    else
      render_error(results[:error], :service_unavailable)
    end
  rescue => e
    Rails.logger.error "WiGLE search error: #{e.message}"
    render_error("WiGLE search failed: #{e.message}", :service_unavailable)
  end
  
  def network_detail
    bssid = params[:bssid]
    return render_error("BSSID parameter required") if bssid.blank?
    
    wigle_service = WigleApiService.new
    result = wigle_service.get_network_detail(bssid)
    
    if result[:success]
      render_success({
        network: result[:network],
        source: 'wigle'
      })
    else
      render_error(result[:error], :not_found)
    end
  rescue => e
    Rails.logger.error "WiGLE network detail error: #{e.message}"
    render_error("Failed to get network details: #{e.message}", :service_unavailable)
  end
  
  def user_stats
    wigle_service = WigleApiService.new
    result = wigle_service.get_user_stats
    
    if result[:success]
      render_success({
        user_stats: result[:stats],
        retrieved_at: Time.current
      })
    else
      render_error(result[:error], :service_unavailable)
    end
  rescue => e
    Rails.logger.error "WiGLE user stats error: #{e.message}"
    render_error("Failed to get user stats: #{e.message}", :service_unavailable)
  end
  
  def test_connection
    wigle_service = WigleApiService.new
    result = wigle_service.test_connection
    
    if result[:success]
      render_success({
        connection: 'successful',
        user: result[:user],
        rank: result[:rank]
      })
    else
      render_error(result[:error], :unauthorized)
    end
  rescue => e
    Rails.logger.error "WiGLE connection test error: #{e.message}"
    render_error("Connection test failed: #{e.message}", :service_unavailable)
  end
  
  def search_by_ssid
    ssid = params[:ssid]
    return render_error("SSID parameter required") if ssid.blank?
    
    wigle_service = WigleApiService.new
    results = wigle_service.search_by_ssid(ssid, search_options)
    
    if results[:success]
      render_success({
        ssid: ssid,
        networks: results[:networks],
        result_count: results[:result_count],
        total_results: results[:total_results]
      })
    else
      render_error(results[:error], :service_unavailable)
    end
  rescue => e
    Rails.logger.error "WiGLE SSID search error: #{e.message}"
    render_error("SSID search failed: #{e.message}", :service_unavailable)
  end
  
  def area_stats
    bounds = extract_bounds_from_params
    return render_error("Geographic bounds required") unless bounds
    
    wigle_service = WigleApiService.new
    results = wigle_service.get_area_stats(bounds)
    
    if results[:success]
      render_success({
        bounds: bounds,
        total_networks: results[:total_networks],
        area_km2: results[:area_km2],
        density_per_km2: results[:density]
      })
    else
      render_error(results[:error], :service_unavailable)
    end
  rescue => e
    Rails.logger.error "WiGLE area stats error: #{e.message}"
    render_error("Area stats failed: #{e.message}", :service_unavailable)
  end
  
  def sync_status
    session_id = params[:session_id]
    
    if session_id.present?
      session = WardriveSession.friendly.find(session_id)
      
      render_success({
        session_id: session.id,
        status: session.status,
        progress: calculate_sync_progress(session),
        networks_synced: session.total_networks || 0,
        started_at: session.start_time,
        completed_at: session.end_time
      })
    else
      # Get all recent WiGLE sync sessions
      recent_syncs = WardriveSession.where(file_format: 'wigle_api')
                                   .order(created_at: :desc)
                                   .limit(10)
      
      sync_statuses = recent_syncs.map do |session|
        {
          session_id: session.id,
          name: session.name,
          status: session.status,
          networks_synced: session.total_networks || 0,
          started_at: session.start_time,
          completed_at: session.end_time
        }
      end
      
      render_success({
        recent_syncs: sync_statuses
      })
    end
  rescue ActiveRecord::RecordNotFound
    render_error("Sync session not found", :not_found)
  rescue => e
    Rails.logger.error "WiGLE sync status error: #{e.message}"
    render_error("Failed to get sync status: #{e.message}")
  end
  
  private
  
  def extract_bounds_from_params
    if params[:bounds].present?
      bounds = params[:bounds]
      
      # Handle different formats
      if bounds.is_a?(String)
        # Parse "south,west,north,east" format
        coords = bounds.split(',').map(&:to_f)
        return nil unless coords.length == 4
        
        {
          south: coords[0],
          west: coords[1],
          north: coords[2], 
          east: coords[3]
        }
      elsif bounds.is_a?(Hash)
        {
          south: bounds[:south]&.to_f || bounds['south']&.to_f,
          west: bounds[:west]&.to_f || bounds['west']&.to_f,
          north: bounds[:north]&.to_f || bounds['north']&.to_f,
          east: bounds[:east]&.to_f || bounds['east']&.to_f
        }
      end
    elsif params[:latitude] && params[:longitude] && params[:radius]
      # Convert center point + radius to bounds
      lat = params[:latitude].to_f
      lng = params[:longitude].to_f
      radius_km = params[:radius].to_f
      
      calculate_bounds_from_center(lat, lng, radius_km)
    end
  end
  
  def calculate_bounds_from_center(lat, lng, radius_km)
    # Convert radius to degrees (rough approximation)
    lat_offset = radius_km / 111.32
    lng_offset = radius_km / (111.32 * Math.cos(lat * Math::PI / 180))
    
    {
      south: lat - lat_offset,
      west: lng - lng_offset,
      north: lat + lat_offset,
      east: lng + lng_offset
    }
  end
  
  def search_options
    {
      results_per_page: [params[:limit]&.to_i || 100, 1000].min,
      first: params[:offset]&.to_i || 0,
      freenet: params[:include_open] != 'false',
      paynet: params[:include_secured] != 'false',
      only_mine: params[:only_mine] == 'true'
    }
  end
  
  def sync_options
    {
      session_name: params[:session_name],
      include_metadata: params[:include_metadata] != 'false',
      max_networks: params[:max_networks]&.to_i
    }
  end
  
  def calculate_sync_progress(session)
    case session.status
    when 'pending'
      0
    when 'processing'
      # Rough estimation based on time elapsed
      elapsed = Time.current - session.start_time
      estimated_duration = 5.minutes # Average sync time
      [(elapsed / estimated_duration * 100).to_i, 95].min
    when 'completed'
      100
    when 'failed'
      -1
    else
      0
    end
  end
end
