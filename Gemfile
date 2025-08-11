source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Enterprise Wardriving Platform Gems
gem 'nokogiri', '~> 1.15'  # For XML/KML parsing
gem 'rubyzip', '~> 2.3'    # For archive handling
gem 'httparty', '~> 0.21'  # For WiGLE.net API integration
gem 'rgeo', '~> 3.0'       # Advanced GIS capabilities
gem 'rgeo-geojson', '~> 2.1'  # GeoJSON support
gem 'rgeo-kml', '~> 0.0.1' # KML parsing
gem 'csv', '~> 3.2'        # Enhanced CSV parsing
gem 'sidekiq', '~> 8.0'    # Background job processing
gem 'redis', '~> 5.0'      # Redis for Sidekiq and caching
gem 'pg', '~> 1.5'         # PostgreSQL for production
gem 'image_processing', '~> 1.2'  # For image variants
gem 'jsonapi-serializer', '~> 2.2'  # Fast JSON API serialization
gem 'kaminari', '~> 1.2'   # Pagination
gem 'ransack', '~> 4.1'    # Advanced search
gem 'friendly_id', '~> 5.5' # SEO friendly URLs
gem 'geocoder', '~> 1.8'   # Geocoding capabilities
gem 'rest-client', '~> 2.1' # HTTP client for AI APIs
gem 'rack-cors', '~> 2.0'      # CORS for API endpoints

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
