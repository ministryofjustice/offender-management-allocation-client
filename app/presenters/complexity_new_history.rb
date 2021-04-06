class ComplexityNewHistory
  def initialize(history)
    @history = history
  end

  def created_at
    @history.fetch(:createdTimeStamp)
  end

  def level
    @history.fetch(:level).titleize
  end

  def prison
    nil
  end

  def to_partial_path
    'case_history/complexity/new'
  end

  def created_by_name
    username = @history[:sourceUser]
    if username
      user = HmppsApi::PrisonApi::UserApi.user_details(username)
      "#{user.last_name}, #{user.first_name}"
    end
  end
end
