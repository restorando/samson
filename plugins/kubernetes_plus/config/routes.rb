# frozen_string_literal: true
Samson::Application.routes.draw do
  resources :projects do
    resources :stages do
      member do
        get :kubernetes_debug, controller: 'kubernetes_plus/stages'
      end
    end
  end
end
