class FileProcessorJob < ApplicationJob
  queue_as :default
  
  def perform(session)
    session.update!(status: 'processing')
    
    begin
      case session.file_format
      when 'csv'
        process_csv_file(session)
      when 'kml'
        process_kml_file(session)
      when 'kismet'
        process_kismet_file(session)
      when 'magic8ball'
        process_magic8ball_file(session)
      else
        raise "Unsupported file format: #{session.file_format}"
      end
      
      # Mark as completed and calculate statistics
      session.update!(status: 'completed')
      
      # Queue AI analysis if enabled
      AiAnalysisJob.perform_later(session) if session.network_observations.count > 100
      
    rescue => e
      Rails.logger.error "File processing failed for session #{session.id}: #{e.message}"
      session.update!(status: 'failed')
      raise e
    end
  end
  
  private
  
  def process_csv_file(session)
    return unless session.data_file.attached?
    
    file_path = ActiveStorage::Blob.service.path_for(session.data_file.key)
    
    CSV.foreach(file_path, headers: true) do |row|
      process_network_data(session, row.to_h)
    end
  end
  
  def process_kml_file(session)
    return unless session.data_file.attached?
    
    file_content = session.data_file.download
    doc = Nokogiri::XML(file_content)
    
    # Parse KML placemarks
    doc.xpath('//kml:Placemark', 'kml' => 'http://www.opengis.net/kml/2.2').each do |placemark|
      coordinates = placemark.xpath('.//kml:coordinates', 'kml' => 'http://www.opengis.net/kml/2.2').text.strip
      name = placemark.xpath('.//kml:name', 'kml' => 'http://www.opengis.net/kml/2.2').text
      description = placemark.xpath('.//kml:description', 'kml' => 'http://www.opengis.net/kml/2.2').text
      
      next if coordinates.empty?
      
      lng, lat, alt = coordinates.split(',').map(&:to_f)
      
      # Parse network data from description or name
      network_data = parse_kml_network_info(name, description)
      network_data.merge!({
        'latitude' => lat,
        'longitude' => lng,
        'altitude' => alt || 0
      })
      
      process_network_data(session, network_data)
    end
  end
  
  def process_kismet_file(session)
    # Kismet XML/NetXML processing
    return unless session.data_file.attached?
    
    file_content = session.data_file.download
    doc = Nokogiri::XML(file_content)
    
    # Process wireless networks
    doc.xpath('//wireless-network').each do |network|
      ssid = network.xpath('.//essid').first&.text
      bssid = network['bssid']
      encryption = network.xpath('.//encryption').first&.text
      
      # Get GPS info
      gps_info = network.xpath('.//gps-info/*').first
      next unless gps_info
      
      network_data = {
        'ssid' => ssid,
        'bssid' => bssid,
        'encryption' => encryption,
        'latitude' => gps_info['lat'].to_f,
        'longitude' => gps_info['lon'].to_f,
        'signal_strength' => network.xpath('.//max_signal_dbm').first&.text&.to_i || -90
      }
      
      process_network_data(session, network_data)
    end
  end
  
  def process_magic8ball_file(session)
    # Custom Magic8ball format processing
    return unless session.data_file.attached?
    
    file_content = session.data_file.download
    
    # Parse Magic8ball format (assuming it's a custom JSON/text format)
    lines = file_content.split("\n")
    lines.each do |line|
      next if line.strip.empty? || line.start_with?('#')
      
      # Parse custom format - adjust based on actual Magic8ball format
      data = JSON.parse(line) rescue nil
      next unless data
      
      process_network_data(session, data)
    end
  end
  
  def process_network_data(session, data)
    # Normalize data
    normalized_data = normalize_network_data(data)
    return unless normalized_data[:bssid] && normalized_data[:latitude] && normalized_data[:longitude]
    
    # Find or create WiFi network
    network = WifiNetwork.find_or_create_by(bssid: normalized_data[:bssid]) do |net|
      net.assign_attributes(normalized_data.except(:latitude, :longitude, :signal_strength, :timestamp))
      net.first_seen = Time.current
    end
    
    # Update network with latest data
    network.update!(
      last_seen: Time.current,
      observation_count: (network.observation_count || 0) + 1
    )
    
    # Create observation
    NetworkObservation.create!(
      wifi_network: network,
      wardrive_session: session,
      latitude: normalized_data[:latitude],
      longitude: normalized_data[:longitude],
      signal_strength: normalized_data[:signal_strength] || -90,
      timestamp: normalized_data[:timestamp] || Time.current,
      altitude: normalized_data[:altitude] || 0,
      gps_accuracy: normalized_data[:gps_accuracy] || 10.0
    )
  end
  
  def normalize_network_data(data)
    {
      ssid: data['ssid'] || data['SSID'] || data[:ssid] || 'Hidden',
      bssid: data['bssid'] || data['BSSID'] || data[:bssid],
      encryption: data['encryption'] || data['Encryption'] || data[:encryption] || 'Unknown',
      frequency: data['frequency'] || data['Frequency'] || data[:frequency],
      channel: data['channel'] || data['Channel'] || data[:channel],
      signal_strength: (data['signal_strength'] || data['SignalStrength'] || data[:signal_strength] || data['rssi'] || data['RSSI']).to_i,
      latitude: (data['latitude'] || data['lat'] || data[:latitude] || data[:lat]).to_f,
      longitude: (data['longitude'] || data['lon'] || data[:longitude] || data[:lon]).to_f,
      altitude: (data['altitude'] || data['alt'] || data[:altitude]).to_f,
      timestamp: parse_timestamp(data['timestamp'] || data['time'] || data[:timestamp]),
      vendor: data['vendor'] || data[:vendor],
      capabilities: data['capabilities'] || data[:capabilities],
      gps_accuracy: (data['accuracy'] || data[:accuracy]).to_f
    }
  end
  
  def parse_timestamp(timestamp_str)
    return Time.current unless timestamp_str
    
    Time.parse(timestamp_str) rescue Time.current
  end
  
  def parse_kml_network_info(name, description)
    # Parse network information from KML name/description
    # This would depend on the specific KML format used
    {
      'ssid' => name,
      'encryption' => description.match(/Encryption: ([^,]+)/i)&.[](1) || 'Unknown',
      'signal_strength' => description.match(/Signal: ([^,]+)/i)&.[](1)&.to_i || -90
    }
  end
end
