# frozen_string_literal: true

class Summary
  attr_accessor :allocated, :unallocated, :pending, :new_arrivals
  def initialize(summary_type, allocated:, unallocated:, pending:, new_arrivals:)
    @summary_type = summary_type
    @allocated = allocated
    @unallocated = unallocated
    @pending = pending
    @new_arrivals = new_arrivals
  end
end
