$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "gcs"

unless ENV["SERVICE_ACCOUNT_JSON"]
  if File.readable?(File.expand_path("../../config/service_account.json", __FILE__))
    json_key = File.read(File.expand_path("../../config/service_account.json", __FILE__))
    ENV["SERVICE_ACCOUNT_JSON"] = json_key
  end
end

RSpec.configure do |config|
  if ENV["SERVICE_ACCOUNT_JSON"]
    $credential_available = true
    config.before(:each) do
      json = JSON.parse(ENV["SERVICE_ACCOUNT_JSON"])
      @email = json["client_email"]
      @private_key = OpenSSL::PKey::RSA.new(json["private_key"])
    end
  else
    $credential_available = false
  end
end
