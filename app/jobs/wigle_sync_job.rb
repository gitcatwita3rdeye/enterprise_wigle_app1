class WigleSyncJob < ApplicationJob
  queue_as :default
  
  def perform(bounds, options = {})
    Rails.logger.info "Starting WiGLE sync job for bounds: #{bounds}"
    
    begin
      wigle_service = WigleApiService.new
      result = wigle_service.sync_to_database(bounds, options[:session_name])
      
      if result[:success]
        Rails.logger.info "WiGLE sync completed successfully: #{result[:synced_count]} networks synced"
        
        # Broadcast success to any listening clients
        ActionCable.server.broadcast(
          "wigle_sync_channel",
          {
            type: 'sync_complete',
            success: true,
            synced_count: result[:synced_count],
            session_id: result[:session].id,
            total_available: result[:total_available]
          }
        )
      else
        Rails.logger.error "WiGLE sync failed: #{result[:error]}"
        
        # Broadcast failure
        ActionCable.server.broadcast(
          "wigle_sync_channel",
          {
            type: 'sync_failed',
            success: false,
            error: result[:error]
          }
        )
      end
      
    rescue => e
      Rails.logger.error "WiGLE sync job failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Broadcast error
      ActionCable.server.broadcast(
        "wigle_sync_channel",
        {
          type: 'sync_error',
          success: false,
          error: e.message
        }
      )
      
      raise e
    end
  end
end
