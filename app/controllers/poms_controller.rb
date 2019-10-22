# frozen_string_literal: true

class PomsController < PrisonsApplicationController
  before_action :load_pom, except: [:show_non_pom, :index, :show, :edit]
  # so that breadcrumb has staff member available
  before_action :load_pom_staff_member, only: [:show, :edit]

  breadcrumb 'Prison Offender Managers',
             -> { prison_poms_path(active_prison_id) }, only: [:index, :show]
  breadcrumb -> { @pom.full_name },
             -> { prison_poms_path(active_prison_id, params[:nomis_staff_id]) },
             only: [:show]

  def index
    poms = PrisonOffenderManagerService.get_poms(active_prison_id)
    @active_poms, @inactive_poms = poms.partition { |pom|
      %w[active unavailable].include? pom.status
    }
  end

  def show
    @caseload = PomCaseload.new(@pom.staff_id, active_prison)
    @allocations = sort_allocations(@caseload.allocations)
  end

  # This is for the situation where the user is no longer a POM
  # the user will probably mark this POM inactive
  def show_non_pom
    @nomis_staff_id = params[:nomis_staff_id]
  end

  def sort_allocations(allocations)
    if params['sort'].present?
      sort_field, sort_direction = params['sort'].split.map(&:to_sym)
    else
      sort_field = :last_name
      sort_direction = :asc
    end

    # cope with nil values by sorting using to_s - only dates and strings in these fields
    allocations = allocations.sort_by { |sentence| sentence.public_send(sort_field).to_s }
    allocations.reverse! if sort_direction == :desc

    allocations
  end

  def edit
    @errors = {}
  end

  def update
    pom_detail = PrisonOffenderManagerService.update_pom(
      nomis_staff_id: params[:nomis_staff_id].to_i,
      working_pattern: working_pattern,
      status: edit_pom_params[:status]
    )

    if pom_detail.valid?
      redirect_to prison_pom_path(active_prison_id, id: params[:nomis_staff_id])
    else
      @pom = StaffMember.new params[:nomis_staff_id], pom_detail
      @errors = pom_detail.errors
      render :edit
    end
  end

private

  def load_pom_staff_member
    @pom = StaffMember.new params[:nomis_staff_id]
  end

  def working_pattern
    return '1.0' if edit_pom_params[:description] == 'FT'

    edit_pom_params[:working_pattern]
  end

  def load_pom
    @pom = PrisonOffenderManagerService.get_pom(active_prison_id, params[:nomis_staff_id])
  end

  def edit_pom_params
    params.require(:edit_pom).permit(:working_pattern, :status, :description)
  end
end
