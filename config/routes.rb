require 'sidekiq/web'

Rails.application.routes.draw do
  # Mount Sidekiq Web UI
  mount Sidekiq::Web => '/sidekiq'
  
  root 'dashboard#index'
  
  # Dashboard
  get 'dashboard', to: 'dashboard#index'
  get 'dashboard/stats', to: 'dashboard#stats'
  
  # File Upload System
  resources :file_uploads, only: [:index, :new, :create, :show, :destroy] do
    member do
      post :process
      get :status
    end
  end
  
  # Network Analysis
  resources :networks do
    collection do
      get :map
      get :graph
      get :analyze
      get :search
      get :export
    end
    member do
      get :details
      get :timeline
    end
  end
  
  # Wardrive Sessions
  resources :wardrive_sessions do
    resources :network_observations, only: [:index, :show]
  end
  
  # API endpoints
  namespace :api do
    namespace :v1 do
      resources :networks, only: [:index, :show]
      resources :sessions, only: [:index, :show]
      get 'stats', to: 'dashboard#stats'
      post 'wigle_sync', to: 'wigle#sync'
    end
  end
  
  # AI Analysis endpoints
  namespace :ai do
    post 'analyze_pattern', to: 'analysis#analyze_pattern'
    post 'predict_coverage', to: 'analysis#predict_coverage'
    post 'anomaly_detection', to: 'analysis#anomaly_detection'
  end
  
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
  
  # PWA files
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
