Rails.application.routes.draw do
  devise_for :users
  root "pages#home"

  resources :stacks, only: [ :index, :show ]
  resources :cards, only: [ :index, :show ]
  resources :wallet_items, only: [ :index, :create, :destroy ]
  resources :quiz_responses, only: [ :new, :create, :show ]

  get "up" => "rails/health#show", as: :rails_health_check
end
