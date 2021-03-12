# frozen_string_literal: true

Rails.application.routes.draw do
  ActiveAdmin.routes(self)
  root to: 'root#index'

  get '/auth/:provider/callback', to: 'sessions#create'
  get '/signout', to: 'sessions#destroy'

  resources :prisons, only: [] do
    resources :prisons, only: :index

    resources :dashboard, only: :index
    resources :handovers, only: :index
    resources :staff do
      resources :caseload, only: %i[index new]
      resources :caseload_handovers, only: %i[index]
    end

    resources :prisoners, only: [:show] do
      collection do
        constraints lambda {
            |request| PrisonService.womens_prison?(request.path_parameters.fetch(:prison_id))
        } do
          get 'allocated' => 'female_prisoners#allocated'
          get 'unallocated' => 'female_prisoners#unallocated'
          get 'missing_information' => 'female_prisoners#missing_information'
          get 'new_arrivals' => 'female_prisoners#new_arrivals'
        end
        get 'summary' => 'summary#index'
        get 'allocated' => 'summary#allocated'
        get 'unallocated' => 'summary#unallocated'
        get 'missing_information' => 'summary#missing_information'
        get 'new_arrivals' => 'summary#new_arrivals'
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

      resources :victim_liaison_officers, only: [:new, :edit, :create, :update, :destroy] do
        member do
          get 'delete'
        end
      end
    end

    resources :allocations, only: %i[ show new create edit update ], param: :nomis_offender_id, path_names: {
        new: ':nomis_offender_id/new',
    }
    get('/allocations/:nomis_offender_id/history' => 'allocations#history', as: 'allocation_history')
    get('/allocations/confirm/:nomis_offender_id/:nomis_staff_id' => 'allocations#confirm', as: 'confirm_allocation')
    get('/reallocations/confirm/:nomis_offender_id/:nomis_staff_id' => 'allocations#confirm_reallocation', as: 'confirm_reallocation')

    resources :case_information, only: %i[new create edit update show], param: :nomis_offender_id, controller: 'case_information', path_names: {
        new: 'new/:nomis_offender_id',
    } do
      get('edit_prd' => 'case_information#edit_prd', as: 'edit_prd', on: :member)
      put('update_prd' => 'case_information#update_prd', as: 'update_prd', on: :member)
    end

    resources :coworking, only: [:new, :create, :destroy], param: :nomis_offender_id, path_names: {
        new: ':nomis_offender_id/new',
    } do
      get('confirm_coworking_removal' => 'coworking#confirm_removal', as: 'confirm_removal')
    end
    get('/coworking/confirm/:nomis_offender_id/:primary_pom_id/:secondary_pom_id' => 'coworking#confirm', as: 'confirm_coworking_allocation')

    #resource :overrides,  only: %i[ new create ], path_names: { new: 'new/:nomis_offender_id/:nomis_staff_id'}
    resource :overrides, only: %i[ new show update], path_names: { new: 'new/:nomis_offender_id/:nomis_staff_id'}
    resources :poms, only: %i[ index show edit update ], param: :nomis_staff_id
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
    get('/search' => 'search#search')
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
