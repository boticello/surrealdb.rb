# frozen_string_literal: true

RSpec.describe 'WebSocket CRUD', :integration do
  let(:client) { new_test_client(SurrealHelper::SURREAL_WS_URL) }

  it_behaves_like 'CRUD operations'
end
