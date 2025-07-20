class WigleApiService
  BASE_URL = 'https://api.wigle.net/api/v2'.freeze
  
  def initialize(api_name = nil, api_token = nil)
    @api_name = api_name || ENV['WIGLE_API_NAME'] || 'AIDd6d675ffa25f40400f2b4d08f52f939b'
    @api_token = api_token || ENV['WIGLE_API_TOKEN'] || 'b67fb1fc7e23eee5dafcc737fbf704cb'
    @encoded_auth = ENV['WIGLE_ENCODED_AUTH'] || 'QUlEZDZkNjc1ZmZhMjVmNDA0MDBmMmI0ZDA4ZjUyZjkzOWI6YjY3ZmIxZmM3ZTIzZWVlNWRhZmNjNzM3ZmJmNzA0Y2I='
  end
  
  # Test API connection
  def test_connection
    response = make_request('/profile/user')
    
    if response['success'] && response['user'].present?
      {
        success: true,
        user: response['user']['userid'],
        rank: response['user']['rank'],
        message: 'Connection successful'
      }
    else
      {
        success: false,
        error: response['message'] || 'Connection failed'
      }
    end
  rescue => e
    Rails.logger.error "WiGLE connection test error: #{e.message}"
    { success: false, error: e.message }
  end
  
  # Search for networks within a geographic boundary
  def search_networks(bounds, options = {})
    params = {
      onlymine: options[:only_mine] || false,
      first: options[:first] || 0,
      freenet: options[:freenet] || true,
      paynet: options[:paynet] || true,
      latrange1: bounds[:south] || bounds['south'],
      latrange2: bounds[:north] || bounds['north'], 
      longrange1: bounds[:west] || bounds['west'],
      longrange2: bounds[:east] || bounds['east'],
      variance: options[:variance] || 0.01,
      house: options[:house] || false,
      resultsPerPage: options[:results_per_page] || 100
    }
    
    response = make_request('/network/search', params)
    
    if response['success']
      {
        success: true,
        networks: parse_wigle_networks(response['results'] || []),
        result_count: response['resultCount'] || 0,
        total_results: response['totalResults'] || 0,
        search_after: response['searchAfter']
      }
    else
      {
        success: false,
        error: response['message'] || 'Search failed'
      }
    end
  rescue => e
    Rails.logger.error "WiGLE API search error: #{e.message}"
    { success: false, error: e.message }
  end
  
  # Get network details by BSSID
  def get_network_detail(bssid)
    params = { netid: bssid }
    
    response = make_request('/network/detail', params)
    
    if response['success'] && response['results'].present?
      {
        success: true,
        network: parse_wigle_network(response['results'].first)
      }
    else
      {
        success: false,
        error: response['message'] || 'Network not found'
      }
    end
  rescue => e
    Rails.logger.error "WiGLE API detail error: #{e.message}"
    { success: false, error: e.message }
  end
  
  # Get user statistics
  def get_user_stats
    response = make_request('/profile/user')
    
    if response['success'] && response['user'].present?
      user = response['user']
      {
        success: true,
        stats: {
          username: user['userid'],
          rank: user['rank'],
          discovered_wifi: user['discoveredWiFiGPS'] || 0,
          discovered_cell: user['discoveredCellGPS'] || 0,
          total_wifi: user['totalWiFiLocations'] || 0,
          total_uploaded: user['totalUploaded'] || 0,
          first_trans: user['first'],
          last_trans: user['last'],
          monthly_ranking: user['monthRank'] || 0,
          prev_monthly_ranking: user['prevMonthRank'] || 0
        }
      }
    else
      {
        success: false,
        error: response['message'] || 'Failed to get user stats'
      }
    end
  rescue => e
    Rails.logger.error "WiGLE user stats error: #{e.message}"
    { success: false, error: e.message }
  end
  
  # Search by SSID
  def search_by_ssid(ssid, options = {})
    params = {
      ssid: ssid,
      onlymine: options[:only_mine] || false,
      first: options[:first] || 0,
      resultsPerPage: options[:results_per_page] || 100
    }
    
    response = make_request('/network/search', params)
    
    if response['success']
      {
        success: true,
        networks: parse_wigle_networks(response['results'] || []),
        result_count: response['resultCount'] || 0,
        total_results: response['totalResults'] || 0
      }
    else
      {
        success: false,
        error: response['message'] || 'SSID search failed'
      }
    end
  rescue => e
    Rails.logger.error "WiGLE SSID search error: #{e.message}"
    { success: false, error: e.message }
  end
  
  # Sync networks from WiGLE to local database
  def sync_to_database(bounds, session_name = nil)
    Rails.logger.info "Starting WiGLE sync for bounds: #{bounds}"
    
    results = search_networks(bounds, { freenet: true, paynet: true, results_per_page: 1000 })
    
    return results unless results[:success]
    
    # Create wardrive session for WiGLE data
    session = WardriveSession.create!(
      name: session_name || "WiGLE Sync #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}",
      description: "Synchronized from WiGLE.net API - #{results[:result_count]} networks",
      file_format: 'wigle_api',
      user_name: 'WiGLE API',
      status: 'processing',
      start_time: Time.current
    )
    
    synced_count = 0
    error_count = 0
    
    results[:networks].each do |wigle_network|
      begin
        next unless wigle_network[:bssid] && wigle_network[:latitude] && wigle_network[:longitude]
        
        # Find or create WiFi network
        network = WifiNetwork.find_or_create_by(bssid: wigle_network[:bssid]) do |net|
          net.ssid = wigle_network[:ssid] || 'Hidden Network'
          net.encryption = wigle_network[:encryption] || 'Unknown'
          net.channel = wigle_network[:channel]
          net.frequency = wigle_network[:frequency]
          net.vendor = wigle_network[:vendor]
          net.latitude = wigle_network[:latitude]
          net.longitude = wigle_network[:longitude]
          net.first_seen = wigle_network[:first_seen] || Time.current
          net.last_seen = wigle_network[:last_seen] || Time.current
          net.observation_count = 1
        end
        
        # Update existing network with latest data
        if network.persisted? && !network.changed?
          network.update!(
            last_seen: [network.last_seen, wigle_network[:last_seen]].compact.max,
            observation_count: (network.observation_count || 0) + 1,
            # Update coordinates if more recent
            latitude: wigle_network[:last_seen] && wigle_network[:last_seen] > network.last_seen ? wigle_network[:latitude] : network.latitude,
            longitude: wigle_network[:last_seen] && wigle_network[:last_seen] > network.last_seen ? wigle_network[:longitude] : network.longitude
          )
        end
        
        # Create network observation
        NetworkObservation.create!(\n          wifi_network: network,\n          wardrive_session: session,\n          latitude: wigle_network[:latitude],\n          longitude: wigle_network[:longitude],\n          signal_strength: wigle_network[:signal_strength] || -80,\n          timestamp: wigle_network[:last_seen] || Time.current,\n          altitude: 0.0,\n          gps_accuracy: wigle_network[:accuracy] || 10.0\n        )\n        \n        synced_count += 1\n        \n        # Log progress every 100 networks\n        if synced_count % 100 == 0\n          Rails.logger.info "WiGLE sync progress: #{synced_count}/#{results[:result_count]} networks processed"\n        end\n        \n      rescue => e\n        error_count += 1\n        Rails.logger.error "Error syncing WiGLE network #{wigle_network[:bssid]}: #{e.message}"\n        next\n      end\n    end\n    \n    # Update session statistics\n    session.update!(\n      status: error_count > synced_count / 2 ? 'failed' : 'completed',\n      end_time: Time.current,\n      total_networks: synced_count,\n      unique_networks: synced_count\n    )\n    \n    Rails.logger.info "WiGLE sync completed: #{synced_count} networks synced, #{error_count} errors"\n    \n    {\n      success: true,\n      synced_count: synced_count,\n      error_count: error_count,\n      session: session,\n      total_available: results[:total_results]\n    }\n  rescue => e\n    session&.update!(status: 'failed', end_time: Time.current)\n    Rails.logger.error "WiGLE sync failed: #{e.message}"\n    { success: false, error: e.message }\n  end\n  \n  # Get statistics for a geographic area\n  def get_area_stats(bounds)\n    results = search_networks(bounds, { results_per_page: 1 })\n    \n    if results[:success]\n      {\n        success: true,\n        total_networks: results[:total_results],\n        area_km2: calculate_area(bounds),\n        density: results[:total_results].to_f / calculate_area(bounds)\n      }\n    else\n      results\n    end\n  end\n  \n  private\n  \n  def make_request(endpoint, params = {})\n    url = "#{BASE_URL}#{endpoint}"\n    \n    # Clean up params - remove nil values\n    clean_params = params.compact\n    \n    response = RestClient.get(\n      url,\n      {\n        params: clean_params,\n        'Authorization' => "Basic #{@encoded_auth}",\n        'Accept' => 'application/json',\n        'User-Agent' => 'WigleViz-Enterprise/1.0'\n      }\n    )\n    \n    JSON.parse(response.body)\n  rescue RestClient::ExceptionWithResponse => e\n    Rails.logger.error "WiGLE API Error: #{e.response&.body}"\n    JSON.parse(e.response.body) rescue { 'success' => false, 'message' => e.message }\n  end\n  \n  def parse_wigle_networks(networks)\n    networks.map { |net| parse_wigle_network(net) }.compact\n  end\n  \n  def parse_wigle_network(network)\n    return nil unless network\n    \n    {\n      ssid: network['ssid'],\n      bssid: network['netid'],\n      encryption: parse_encryption(network['wep']),\n      channel: network['channel']&.to_i,\n      frequency: calculate_frequency(network['channel']&.to_i),\n      signal_strength: -70, # WiGLE doesn't provide signal strength in search\n      latitude: network['trilat']&.to_f,\n      longitude: network['trilong']&.to_f,\n      country: network['country'],\n      region: network['region'],\n      city: network['city'],\n      postal_code: network['postalcode'],\n      road: network['road'],\n      first_seen: parse_wigle_date(network['firsttime']),\n      last_seen: parse_wigle_date(network['lasttime']),\n      vendor: determine_vendor(network['netid']),\n      accuracy: 10.0 # Default GPS accuracy\n    }\n  end\n  \n  def parse_encryption(wep_value)\n    case wep_value&.upcase\n    when 'Y'\n      'WEP'\n    when 'N'\n      'Open'\n    when 'W'\n      'WPA'\n    when '2'\n      'WPA2'\n    when '3'\n      'WPA3'\n    when '?'\n      'Unknown'\n    else\n      wep_value || 'Unknown'\n    end\n  end\n  \n  def parse_wigle_date(date_string)\n    return nil unless date_string\n    \n    # WiGLE dates are in format: 2024-01-15 12:30:45\n    Time.parse(date_string) rescue nil\n  end\n  \n  def calculate_frequency(channel)\n    return nil unless channel\n    \n    # Standard WiFi channel to frequency mapping\n    if channel <= 14\n      # 2.4 GHz band\n      2407 + (channel * 5)\n    elsif channel >= 36 && channel <= 165\n      # 5 GHz band\n      5000 + (channel * 5)\n    else\n      nil\n    end\n  end\n  \n  def determine_vendor(bssid)\n    return 'Unknown' unless bssid\n    \n    # Extract OUI (first 3 octets)\n    oui = bssid.split(':')[0..2].join(':').upcase\n    \n    # Common vendor OUIs (simplified)\n    vendor_map = {\n      '00:1B:63' => 'Apple',\n      '00:23:DF' => 'Apple',\n      '00:25:00' => 'Apple',\n      '40:A6:D9' => 'Apple',\n      '58:55:CA' => 'Apple',\n      '00:1F:3F' => 'Cisco',\n      '00:26:99' => 'Cisco',\n      '00:50:56' => 'VMware',\n      '00:15:5D' => 'Microsoft',\n      '00:16:3E' => 'Xensource',\n      '00:1C:42' => 'Parallels'\n    }\n    \n    vendor_map[oui] || 'Unknown'\n  end\n  \n  def calculate_area(bounds)\n    # Rough calculation of area in km²\n    lat_diff = (bounds[:north] || bounds['north']).to_f - (bounds[:south] || bounds['south']).to_f\n    lng_diff = (bounds[:east] || bounds['east']).to_f - (bounds[:west] || bounds['west']).to_f\n    \n    # Convert degrees to km (rough approximation)\n    lat_km = lat_diff * 111.32\n    lng_km = lng_diff * 111.32 * Math.cos((bounds[:north].to_f + bounds[:south].to_f) / 2 * Math::PI / 180)\n    \n    (lat_km * lng_km).abs\n  end\nend
