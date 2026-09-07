Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "pages#home"
  get "questionnaire", to: "pages#questionnaire"
  get "results", to: "pages#results"
  get "compare", to: "pages#compare"
  get "wallet", to: "pages#wallet"
  get "explore", to: "pages#explore"
  get "cards/:id", to: "pages#card_detail", as: :card_detail
  post "chat", to: "chat#create"
end
