# frozen_string_literal: true

RSpec.describe 'WebSocket Auth', :integration do
  let(:client) { new_test_client(SurrealHelper::SURREAL_WS_URL) }

  it_behaves_like 'auth operations'
end
