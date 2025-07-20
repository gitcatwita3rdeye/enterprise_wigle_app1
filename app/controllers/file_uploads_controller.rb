class FileUploadsController < ApplicationController
  before_action :set_session, only: [:show, :process, :status, :destroy]
  
  def index
    @sessions = WardriveSession.recent.page(params[:page]).per(20)
    @total_networks = WifiNetwork.count
    @total_sessions = WardriveSession.count
  end

  def new
    @session = WardriveSession.new
  end

  def create
    @session = WardriveSession.new(session_params)
    
    if @session.save
      if params[:data_file].present?
        @session.data_file.attach(params[:data_file])
        # Queue background processing
        FileProcessorJob.perform_later(@session)
        redirect_to @session, notice: 'File uploaded successfully! Processing started.'
      else
        redirect_to @session, alert: 'Please select a file to upload.'
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @observations = @session.network_observations.includes(:wifi_network).recent.limit(100)
    @stats = calculate_session_stats
  end

  def process
    FileProcessorJob.perform_later(@session)
    redirect_to @session, notice: 'File reprocessing started.'
  end

  def status
    render json: {
      status: @session.status,
      progress: calculate_progress,
      total_networks: @session.total_networks,
      unique_networks: @session.unique_networks,
      processing_time: @session.duration_formatted
    }
  end

  def destroy
    @session.destroy
    redirect_to file_uploads_path, notice: 'Session deleted successfully.'
  end

  private

  def set_session
    @session = WardriveSession.friendly.find(params[:id])
  end

  def session_params
    params.require(:wardrive_session).permit(
      :name, :description, :user_name, :device_info, :file_format
    )
  end

  def calculate_progress
    return 0 if @session.status == 'pending'
    return 100 if @session.status == 'completed'
    return -1 if @session.status == 'failed'
    
    # Rough progress estimation for processing
    case @session.status
    when 'processing'
      rand(20..80) # Simulated progress
    else
      0
    end
  end

  def calculate_session_stats
    {
      total_observations: @session.network_observations.count,
      unique_networks: @session.wifi_networks.distinct.count,
      open_networks: @session.wifi_networks.joins(:network_observations)
                            .where(network_observations: { wardrive_session: @session })
                            .where(encryption: ['Open', 'None', '']).distinct.count,
      coverage_area: @session.coverage_area.round(2),
      strongest_signal: @session.network_observations.maximum(:signal_strength) || 0,
      weakest_signal: @session.network_observations.minimum(:signal_strength) || 0,
      avg_signal: @session.network_observations.average(:signal_strength)&.round(2) || 0
    }
  end
end
