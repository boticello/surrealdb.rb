# frozen_string_literal: true

RSpec.describe "HTTP Auth", :integration do
  let(:client) { new_test_client(SurrealHelper::SURREAL_HTTP_URL) }

  include_examples "auth operations"
end
