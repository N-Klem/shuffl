Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "pages#home"
  get "questionnaire", to: "pages#questionnaire"
  get "results", to: "pages#results"
  get "wallet", to: "pages#wallet"
  post "chat", to: "chat#create"
end
