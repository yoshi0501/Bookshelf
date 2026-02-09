# frozen_string_literal: true

Rails.application.routes.draw do
  # Devise routes with custom controllers
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }

  # 登録中のパスワード確認（ログイン中のみ）
  post "users/verify_password", to: "users/registrations#verify_password", as: :verify_password_user

  # Root
  root "pages#home"

  # Dashboard
  get "dashboard", to: "dashboard#index"

  # Pending approval page
  get "pending_approval", to: "pages#pending_approval"

  # Main resources
  resources :customers do
    member do
      get :download_invoice
      get :download_invoices_by_center
      get :download_statement
    end
    collection do
      get :import
      post :import
      get :download_invoices_bulk
    end
  end
  resources :items do
    collection do
      get :import
      post :import
    end
  end

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

  # Order approval requests
  resources :order_approval_requests, only: %i[index show] do
    member do
      post :approve
      post :reject
    end
  end

  # Admin namespace
  namespace :admin do
    resource :issuer_setting, only: %i[show edit update], path: "issuer"
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
