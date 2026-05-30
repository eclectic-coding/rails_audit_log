require "rails_helper"
require "minitest"
require "rails_audit_log/minitest_assertions"

RSpec.describe RailsAuditLog::MinitestAssertions do
  let(:ctx) do
    Class.new(Minitest::Test) do
      include RailsAuditLog::MinitestAssertions
    end.new("placeholder")
  end

  let(:post) { Post.create!(title: "test") }

  describe "assert_audit_log_entry" do
    it "passes when the record has any audit entry" do
      expect { ctx.assert_audit_log_entry(post) }.not_to raise_error
    end

    it "fails when no entry matches" do
      expect { ctx.assert_audit_log_entry(post, event: :update) }
        .to raise_error(Minitest::Assertion)
    end

    it "passes with an event filter when a matching entry exists" do
      expect { ctx.assert_audit_log_entry(post, event: :create) }.not_to raise_error
    end

    it "passes with a touching filter when a matching entry exists" do
      post.update!(title: "new title")
      expect { ctx.assert_audit_log_entry(post, event: :update, touching: :title) }
        .not_to raise_error
    end

    it "fails with a touching filter when no matching entry" do
      post.update!(title: "new title")
      expect { ctx.assert_audit_log_entry(post, event: :update, touching: :body) }
        .to raise_error(Minitest::Assertion)
    end

    it "includes record class and id in the default failure message" do
      error = nil
      begin
        ctx.assert_audit_log_entry(post, event: :update)
      rescue Minitest::Assertion => e
        error = e
      end
      expect(error.message).to include("Post")
      expect(error.message).to include("update")
    end

    it "uses a custom message when provided" do
      error = nil
      begin
        ctx.assert_audit_log_entry(post, event: :update, message: "my custom message")
      rescue Minitest::Assertion => e
        error = e
      end
      expect(error.message).to include("my custom message")
    end
  end

  describe "refute_audit_log_entry" do
    it "passes when no matching entry exists" do
      expect { ctx.refute_audit_log_entry(post, event: :update) }.not_to raise_error
    end

    it "fails when a matching entry exists" do
      expect { ctx.refute_audit_log_entry(post, event: :create) }
        .to raise_error(Minitest::Assertion)
    end

    it "passes with a touching filter when no matching entry" do
      post.update!(title: "new title")
      expect { ctx.refute_audit_log_entry(post, event: :update, touching: :body) }
        .not_to raise_error
    end

    it "includes 'not to have' in the default failure message" do
      error = nil
      begin
        ctx.refute_audit_log_entry(post, event: :create)
      rescue Minitest::Assertion => e
        error = e
      end
      expect(error.message).to include("not to have")
    end

    it "uses a custom message when provided" do
      error = nil
      begin
        ctx.refute_audit_log_entry(post, event: :create, message: "my refute message")
      rescue Minitest::Assertion => e
        error = e
      end
      expect(error.message).to include("my refute message")
    end
  end
end
