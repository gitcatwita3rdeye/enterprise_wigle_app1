require 'sidekiq'
require 'sidekiq/web'

# Redis configuration
redis_config = {
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
  network_timeout: 5
}

# Configure Sidekiq
Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

# Basic auth for Sidekiq web UI in production
if Rails.env.production?
  Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
    # Use environment variables for credentials
    user == ENV.fetch('SIDEKIQ_USERNAME', 'admin') &&
    password == ENV.fetch('SIDEKIQ_PASSWORD', 'password')
  end
end
