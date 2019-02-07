Rails.application.routes.draw do
  root to: 'dashboard#index'

  get '/status', to: 'status#index'
  get '/auth/:provider/callback', to: 'sessions#create'
  get '/signout', to: 'sessions#destroy'

  get('health' => 'health#index')

  get('/allocations' => 'allocations#index')
  get('/allocations/allocated' => 'allocations#allocated')
  get('/allocations/awaiting' => 'allocations#awaiting')
  get('/allocations/missing-information' => 'allocations#missing_information')

  get('/poms' => 'poms#index')
  get('/poms/:id' => 'poms#show', as: 'poms_show')
  get('/poms/:id/edit' => 'poms#edit', as: 'poms_edit')

  get('/prisoners/:id' => 'prisoners#show', as: 'prisoners_show')

  get('/allocate/:nomis_offender_id' => 'allocate#show',
      as: 'allocate_show')
  get('/allocate/confirm/:nomis_offender_id/:nomis_staff_id' => 'allocate#new',
      as: 'allocate_new')
  post('/allocate/create/:nomis_offender_id/:nomis_staff_id' => 'allocate#create',
      as: 'allocate_create')
end
