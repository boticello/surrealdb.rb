# frozen_string_literal: true

RSpec.describe "WebSocket Live Queries", :integration do
  let(:client) { new_test_client(SurrealHelper::SURREAL_WS_URL) }
  let(:table) { unique_table("live") }

  after { client.close }

  it "receives create notifications" do
    live_id = client.live(table)
    expect(live_id).to be_a(String)

    notifications = Queue.new
    client.subscribe(live_id) { |n| notifications.push(n) }

    client.create(table, { "name" => "Alice" })

    # Wait briefly for the notification
    notification = nil
    5.times do
      begin
        notification = notifications.pop(true)
        break
      rescue ThreadError
        sleep 0.2
      end
    end

    expect(notification).not_to be_nil
    expect(notification["action"]).to eq("CREATE").or(eq("create"))

    client.kill(live_id)
  end
end
