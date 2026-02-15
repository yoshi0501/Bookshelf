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

  resources :manufacturers

  # 発送依頼（メーカー別）。PDF を先に定義して /pdf を manufacturer_id と誤マッチさせない
  get "shipping_requests", to: "shipping_requests#index", as: :shipping_requests
  get "shipping_requests/:manufacturer_id/pdf", to: "shipping_requests#pdf", as: :shipping_request_pdf
  patch "shipping_requests/:manufacturer_id/register_shipment", to: "shipping_requests#register_shipment", as: :register_shipping_request_shipment
  post "shipping_requests/:manufacturer_id/register_shipment_import", to: "shipping_requests#register_shipment_import", as: :register_shipping_request_shipment_import
  get "shipping_requests/:manufacturer_id/shipment_template", to: "shipping_requests#shipment_template", as: :shipment_template_shipping_request
  get "shipping_requests/:manufacturer_id", to: "shipping_requests#show", as: :shipping_request

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
    resources :company_payments, only: %i[index show new create edit update destroy]
    resources :access_logs, only: %i[index]

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
