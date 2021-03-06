class TestTrack::Visitor
  include TestTrack::RequiredOptions

  attr_reader :id

  def initialize(opts = {})
    opts = opts.dup
    @id = opts.delete(:id)
    @assignments = opts.delete(:assignments)
    unless id
      @id = SecureRandom.uuid
      @assignments ||= [] # If we're generating a visitor, we don't need to fetch the assignments
    end
    raise "unknown opts: #{opts.keys.to_sentence}" if opts.present?
  end

  def vary(split_name, opts = {})
    opts = opts.dup
    split_name = split_name.to_s
    context = require_option!(opts, :context)
    raise "unknown opts: #{opts.keys.to_sentence}" if opts.present?

    raise ArgumentError, "must provide block to `vary` for #{split_name}" unless block_given?
    v = TestTrack::VaryDSL.new(assignment: assignment_for(split_name), context: context, split_registry: split_registry)
    yield v
    v.send :run
  end

  def ab(split_name, opts = {}) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    opts = opts.dup
    split_name = split_name.to_s
    true_variant = opts.delete(:true_variant)
    context = require_option!(opts, :context)
    raise "unknown opts: #{opts.keys.to_sentence}" if opts.present?

    ab_configuration = TestTrack::ABConfiguration.new split_name: split_name, true_variant: true_variant, split_registry: split_registry

    vary(split_name, context: context) do |v|
      v.when ab_configuration.variants[:true] do
        true
      end
      v.default ab_configuration.variants[:false] do
        false
      end
    end
  end

  def assignment_registry
    @assignment_registry ||= assignments.each_with_object({}) do |assignment, hsh|
      hsh[assignment.split_name] = assignment
    end
  end

  def unsynced_assignments
    @unsynced_assignments ||= assignment_registry.values.select(&:unsynced?)
  end

  def assignment_json
    assignment_registry.values.each_with_object({}) do |assignment, hsh|
      hsh[assignment.split_name] = assignment.variant
    end
  end

  def split_registry
    @split_registry ||= TestTrack::Remote::SplitRegistry.to_hash
  end

  def link_identifier!(identifier_type, identifier_value)
    identifier_opts = { identifier_type: identifier_type, visitor_id: id, value: identifier_value.to_s }
    begin
      identifier = TestTrack::Remote::Identifier.create!(identifier_opts)
      merge!(identifier.visitor)
    rescue *TestTrack::SERVER_ERRORS => e
      Rails.logger.error "TestTrack failed to link identifier, retrying. #{e}"

      # If at first you don't succeed, async it - we may not display 100% consistent UX this time,
      # but subsequent requests will be better off
      TestTrack::Remote::Identifier.delay.create!(identifier_opts)
    end
  end

  def offline?
    @tt_offline
  end

  def loaded?
    !offline? && @remote_visitor.present?
  end

  def id_overridden_by_existing_visitor?
    @id_overridden_by_existing_visitor || false
  end

  private

  def assignments
    @assignments ||= (remote_visitor && remote_visitor.assignments) || []
  end

  def remote_visitor
    @remote_visitor ||= TestTrack::Remote::Visitor.find(id) unless tt_offline?
  rescue *TestTrack::SERVER_ERRORS => e
    Rails.logger.error "TestTrack failed to load remote visitor. #{e}"
    @tt_offline = true
    nil
  end

  def merge!(other)
    @id_overridden_by_existing_visitor = id != other.id
    @id = other.id
    @assignment_registry = assignment_registry.merge(other.assignment_registry)
    @unsynced_assignments = nil
  end

  def tt_offline?
    @tt_offline || false
  end

  def assignment_for(split_name)
    fetch_assignment_for(split_name) || generate_assignment_for(split_name)
  end

  def fetch_assignment_for(split_name)
    assignment_registry[split_name] if assignment_registry
  end

  def generate_assignment_for(split_name)
    assignment_registry[split_name] = TestTrack::Assignment.new(visitor: self, split_name: split_name)
  end
end
