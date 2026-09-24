# config/initializers/commerce7.rb reads these from Rails credentials, which
# CI doesn't have (no config/master.key). Fixed test values instead.
RSpec.configure do |config|
  config.before do
    Commerce7.configuration.app_credentials = -> { [ "c7-app-id", "c7-app-secret" ] }
    Commerce7.configuration.webhook_credentials = -> { [ "c7-user", "c7-pass" ] }
  end
end
