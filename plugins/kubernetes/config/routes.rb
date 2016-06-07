Samson::Application.routes.draw do
  resources :projects do
    # FIXME: move into kubernetes namespace
    resources :kubernetes_releases, only: [:new, :create, :index, :show]
    resources :kubernetes_dashboard, only: [:index]

    # FIXME: make these proper resources
    member do
      get 'kubernetes', to: 'kubernetes_project#show'
      get 'kubernetes/releases', to: 'kubernetes_project#show'
      get 'kubernetes/releases/new', to: 'kubernetes_project#show'
      get 'kubernetes/dashboard', to: 'kubernetes_project#show'
    end

    namespace :kubernetes do
      resources :roles, except: :edit do
        collection do
          post :seed
        end
      end
      resources :tasks, except: :edit, path: :tasks do
        collection do
          post :seed
        end
        member do
          post :run
        end
        resources :kubernetes_jobs, only: [:new, :create, :index], path: :jobs
      end
    end
  end

  namespace :admin do
    namespace :kubernetes do
      resources :clusters, except: :destroy
      resources :deploy_group_roles
    end
  end
end
