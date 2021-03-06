# frozen_string_literal: true

class CaseloadHandoversController < PrisonStaffApplicationController
  before_action :ensure_signed_in_pom_is_this_pom, :load_pom

  def index
    collection = sort_collection(@pom.allocations.select(&:approaching_handover?), default_sort: :last_name)

    @offenders = Kaminari.paginate_array(collection).page(page)
    @pending_handover_count = collection.count
    @prison_total_handovers = @prison.offenders.count(&:approaching_handover?)
  end
end
