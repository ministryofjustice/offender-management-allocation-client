class OffenderEvent < ApplicationRecord
  validates :nomis_offender_id, :event, :happened_at, presence: true

  enum triggered_by: { user: 'user', system: 'system' }, _prefix: true
  validates :triggered_by, presence: true, inclusion: { in: triggered_bies.keys }
  validates :triggered_by_nomis_username, presence: true, if: :triggered_by_user?
  
  enum event: {
    allocate_primary_pom: 'allocate_primary_pom',
    reallocate_primary_pom: 'reallocate_primary_pom',
    allocate_coworking_pom: 'allocate_coworking_pom',
    reallocate_coworking_pom: 'reallocate_coworking_pom',
    deallocate_primary_pom: 'deallocate_primary_pom',
    deallocate_coworking_pom: 'deallocate_coworking_pom',
    deallocate_poms: 'deallocate_poms'
  }
  validates :event, presence: true, inclusion: { in: events.keys }

  # Return metadata as a hash 'with_indifferent_access' so keys are accessible as symbols or strings
  def metadata
    self[:metadata].with_indifferent_access unless self[:metadata].nil?
  end
end
