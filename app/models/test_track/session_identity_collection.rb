class TestTrack::SessionIdentityCollection
  def initialize(controller)
    @controller = controller
  end

  def include?(identity)
    found_identity = identities[identity.test_track_identifier_type] || authenticated_resource_for_identity(identity)
    found_identity.present? && found_identity == identity
  end

  def <<(identity)
    identities[identity.test_track_identifier_type] = identity
  end

  private

  attr_reader :controller

  def identities
    @identities ||= {}
  end

  def authenticated_resource_for_identity(identity)
    authenticated_resource_method_name = "current_#{identity.class.model_name.element}"

    # pass true to `respond_to?` to include private methods
    controller.respond_to?(authenticated_resource_method_name, true) && controller.send(authenticated_resource_method_name)
  end
end
