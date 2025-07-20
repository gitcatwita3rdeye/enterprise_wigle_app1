class Api::V1::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  private
  
  def render_success(data = {}, message = nil)
    render json: {
      success: true,
      message: message,
      data: data,
      timestamp: Time.current.iso8601
    }
  end
  
  def render_error(message, status = :unprocessable_entity, errors = {})
    render json: {
      success: false,
      error: message,
      errors: errors,
      timestamp: Time.current.iso8601
    }, status: status
  end
  
  def render_paginated(records, serializer = nil)
    if serializer
      serialized_data = serializer.new(records).serializable_hash
    else
      serialized_data = records
    end
    
    render json: {
      success: true,
      data: serialized_data,
      pagination: pagination_metadata(records),
      timestamp: Time.current.iso8601
    }
  end
  
  def pagination_metadata(records)
    return {} unless records.respond_to?(:current_page)
    
    {
      current_page: records.current_page,
      per_page: records.limit_value,
      total_count: records.total_count,
      total_pages: records.total_pages,
      has_next: records.next_page.present?,
      has_prev: records.prev_page.present?
    }
  end
end
