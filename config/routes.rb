Rails.application.routes.draw do
  devise_for :users
  root "pages#home"
  resource :assistant_chat, only: [:show, :create, :destroy]

  resources :stacks, only: [ :index, :show ]
  resources :cards, only: [ :index, :show ]
  resources :reward_estimates, only: [ :create ]
  resources :wallet_items, only: [ :index, :create, :update, :destroy ] do
    patch :preferences, on: :collection
    post :save_browse, on: :collection
    post :save_stack, on: :collection
  end
  resources :quiz_responses, only: [ :new, :create, :show ] do
    post :save_progress, on: :collection
  end

  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
