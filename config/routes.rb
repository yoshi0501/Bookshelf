# frozen_string_literal: true

Rails.application.routes.draw do
  # Devise routes with custom controllers
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }

  # Root
  root "pages#home"

  # Dashboard
  get "dashboard", to: "dashboard#index"

  # Pending approval page
  get "pending_approval", to: "pages#pending_approval"

  # Main resources
  resources :customers
  resources :items

  resources :orders do
    member do
      post :ship
      post :deliver
      post :cancel
    end
    collection do
      get :export
    end
  end

  # Admin namespace
  namespace :admin do
    resources :companies, except: [:destroy]

    resources :approval_requests, only: %i[index show] do
      member do
        post :approve
        post :reject
      end
    end

    resources :user_profiles, only: %i[index show edit update] do
      member do
        post :change_role
      end
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
