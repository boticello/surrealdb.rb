# frozen_string_literal: true

RSpec.describe "WebSocket Live Queries", :integration do
  let(:client) { new_test_client(SurrealHelper::SURREAL_WS_URL) }
  let(:table) { unique_table("live") }

  after { client.close }

  it "receives create notifications" do
    live_id = client.live(table)
    expect(live_id).not_to be_nil

    notifications = Queue.new
    client.subscribe(live_id.to_s) { |n| notifications.push(n) }

    sleep 0.1
    client.create(table, { "name" => "Alice" })

    notification = nil
    10.times do
      begin
        notification = notifications.pop(true)
        break
      rescue ThreadError
        sleep 0.3
      end
    end

    expect(notification).not_to be_nil
    action = notification["action"] || notification[:action]
    expect(action.to_s.downcase).to eq("create")

    client.kill(live_id.to_s)
  end
end
