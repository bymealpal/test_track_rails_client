require 'rails_helper'

RSpec.describe TestTrack::AnalyticsEvent do
  let(:assignment) do
    instance_double(
      TestTrack::Assignment,
      visitor_id: 34,
      split_name: "foo_experiment",
      variant: "treatment",
      context: "home_page",
      feature_gate?: false
    )
  end

  subject { described_class.new(assignment) }

  describe "#assignment" do
    it "returns the analytics_event's assignment" do
      expect(subject.assignment).to eq assignment
    end
  end

  describe "#visitor_id" do
    it "returns the assignment's visitor_id" do
      expect(subject.visitor_id).to eq 34
    end
  end

  describe "#name" do
    it "returns split_assigned" do
      expect(subject.name).to eq "split_assigned"
    end

    context "with a feature gate" do
      let(:assignment) do
        instance_double(
          TestTrack::Assignment,
          visitor_id: 34,
          split_name: "foo_enabled",
          variant: "true",
          context: "home_page",
          feature_gate?: true
        )
      end

      it "returns feature_gate_experienced" do
        expect(subject.name).to eq "feature_gate_experienced"
      end
    end
  end

  describe "#properties" do
    it "returns a hash with relevant facts about the assignment" do
      expect(subject.properties).to eq(
        test_track_visitor_id: 34,
        split_name: "foo_experiment",
        split_variant: "treatment",
        split_context: "home_page"
      )
    end
  end
end
