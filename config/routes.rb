# frozen_string_literal: true

Rails.application.routes.draw do
  ActiveAdmin.routes(self)
  root to: 'root#index'

  get '/auth/:provider/callback', to: 'sessions#create'
  get '/signout', to: 'sessions#destroy'

  resources :prisons, only: [] do
    # Prison switcher - starting from an existing prison
    resources :prisons, only: :index

    resources :dashboard, only: :index
    resources :handovers, only: :index
    resources :staff do
      get 'caseload' => 'caseload#index'
      get 'new_cases' => 'caseload#new_cases'
      resources :caseload_handovers, only: %i[index]
    end

    resources :prisoners, only: [:show] do
      constraints lambda {
        |request| !PrisonService.womens_prison?(request.path_parameters.fetch(:prison_id))
      } do
        get 'new_missing_info' => 'case_information#new'
      end

      constraints lambda {
        |request| PrisonService.womens_prison?(request.path_parameters.fetch(:prison_id))
      } do
        get 'new_missing_info' => 'female_missing_infos#new'
        resource :female_missing_info, only: [:show, :update]
      end

      resource :female_missing_info, only: [:new, :show, :update]

      collection do
        get 'allocated'
        get 'unallocated'
        get 'missing_information'
        get 'new_arrivals'
        get 'search'
      end

      scope :format => true, :constraints => { :format => 'jpg' } do
        get('image' => 'prisoners#image', as: 'image')
      end

      resources :early_allocations, only: [:new, :index, :show] do
        collection do
          post 'oasys_date'
          post 'eligible'
          post 'discretionary'
          post 'confirm_with_reason'
        end
      end

      # edit action always updates the most recent assessment
      # uses `as: :latest_early_allocation` to avoid clashes with `resources :early_allocations` above
      resource :early_allocation, only: [:edit, :update], as: :latest_early_allocation

      resource :complexity_level, only: [:edit, :update]

      resource :complexity_level_allocation, only: [:edit, :update]

      resources :victim_liaison_officers, only: [:new, :edit, :create, :update, :destroy] do
        member do
          get 'delete'
        end
      end

      resources :staff, only: %i[index], controller: 'allocation_staff' do
        resources :build_allocations, only: %i[new show update], controller: 'build_allocations'
      end

      resource :allocation, only: %i[show] do
        member do
          get 'history'
        end
      end
    end

    resources :coworking, only: [:new, :create, :destroy], param: :nomis_offender_id, path_names: {
      new: ':nomis_offender_id/new',
    } do
      get('confirm_coworking_removal' => 'coworking#confirm_removal', as: 'confirm_removal')
    end
    get('/coworking/confirm/:nomis_offender_id/:primary_pom_id/:secondary_pom_id' => 'coworking#confirm', as: 'confirm_coworking_allocation')

    resources :case_information, only: %i[new create edit update show], param: :prisoner_id, controller: 'case_information', path_names: {
        new: 'new/:prisoner_id',
    } do
      get('edit_prd' => 'case_information#edit_prd', as: 'edit_prd', on: :member)
      put('update_prd' => 'case_information#update_prd', as: 'update_prd', on: :member)
    end

    resources :poms, only: %i[ index show edit update ], param: :nomis_staff_id
    # routes to show the 2 tabs on PomsController#show
    get "poms/:nomis_staff_id/tabs/:tab", to: "poms#show", as: :show_pom_tab

    get '/poms/:nomis_staff_id/non_pom' => 'poms#show_non_pom', as: 'pom_non_pom'

    resources :tasks, only: %i[ index ]

    resources :responsibilities, only: %i[new create destroy], param: :nomis_offender_id do
      member do
        get :confirm_removal
      end
      collection do
        post('confirm' => 'responsibilities#confirm')
      end
    end

    get('/debugging' => 'debugging#debugging')
    get('/debugging/prison' => 'debugging#prison_info')
  end

  match "/401", :to => "errors#unauthorized", :via => :all
  match "/404", :to => "errors#not_found", :via => :all, constraints: lambda { |req| req.format == :html }
  match "/500", :to => "errors#internal_server_error", :via => :all
  match "/503", :to => "errors#internal_server_error", :via => :all

  get '/contact_us', to: 'pages#contact_us'
  post '/contact_us', to: 'pages#create_contact_us'
  get '/help', to: 'pages#help'
  get '/help_step0', to: 'pages#help_step0'
  get '/help_step1', to: 'pages#help_step1'
  get '/help_step2', to: 'pages#help_step2'
  get '/help_step3', to: 'pages#help_step3'
  get '/help_step4', to: 'pages#help_step4'
  get '/help_step5', to: 'pages#help_step5'
  get '/help_step6', to: 'pages#help_step6'
  get '/update_case_information', to: 'pages#update_case_information'
  get '/updating_ndelius', to: 'pages#updating_ndelius'
  get '/missing_cases', to: 'pages#missing_cases'
  get '/repatriated', to: 'pages#repatriated'
  get '/scottish_northern_irish', to: 'pages#scottish_northern_irish'
  get '/contact', to: 'pages#contact'
  get '/whats-new', to: 'pages#whats_new'

  resources :health, only: %i[ index ], controller: 'health'
  resources :status, only: %i[ index ], controller: 'status'

  namespace :api do
    get('/' => 'api#index')
    resources :allocation, only: [:show], param: :offender_no, controller: 'allocation_api',path_names: { show: ':offender_no' }
    resources :offenders, only: [:show], param: :nomis_offender_id
  end

  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  mount Flipflop::Engine => "/flip-flop-admin"

  # Sidekiq admin interface
  constraints lambda {|request| SsoIdentity.new(request.session).current_user_is_admin?} do
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
  # Redirect to 'unauthorized' page if user isn't an admin
  get '/sidekiq', :to => redirect('/401')
end
