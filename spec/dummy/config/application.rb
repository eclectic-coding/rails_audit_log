require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)
require "rails_audit_log"

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.1
    config.eager_load = false

    # Encryption keys used only in the test/development dummy app.
    config.active_record.encryption.primary_key        = "ral-test-primary-key-00000000001"
    config.active_record.encryption.deterministic_key  = "ral-test-deterministic-key-00001"
    config.active_record.encryption.key_derivation_salt = "ral-test-kdf-salt-0000000000001"
  end
end
