module RailsAuditLog
  # Opt-in test helper for suppressing audit writes in test setup code.
  #
  # == Setup
  #
  #   # spec/rails_helper.rb
  #   require "rails_audit_log/test_helpers"
  #
  #   RSpec.configure do |config|
  #     config.include RailsAuditLog::TestHelpers
  #   end
  #
  # == Usage
  #
  #   let(:post) { without_audit_log { Post.create!(title: "fixture") } }
  module TestHelpers
    # Executes the block with audit logging disabled. A prefix-free wrapper
    # around {RailsAuditLog.disable} intended for use in FactoryBot factories,
    # +let+ blocks, and other test setup where audit noise is unwanted.
    #
    # @yield executes the block without recording any audit entries
    # @return [Object] the return value of the block
    def without_audit_log(&block)
      RailsAuditLog.disable(&block)
    end
  end
end
