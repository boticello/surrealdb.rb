# frozen_string_literal: true

RSpec.describe SurrealDB::ServerError do
  describe ".from_response" do
    it "creates a basic server error" do
      err = described_class.from_response({
        "code" => -32_000,
        "message" => "something went wrong"
      })
      expect(err).to be_a(SurrealDB::ServerError)
      expect(err.code).to eq(-32_000)
      expect(err.message).to eq("something went wrong")
    end

    it "maps NotFound kind to NotFoundError" do
      err = described_class.from_response({
        "kind" => "NotFound",
        "message" => "table not found"
      })
      expect(err).to be_a(SurrealDB::NotFoundError)
      expect(err.kind).to eq("NotFound")
    end

    it "maps NotAllowed kind to NotAllowedError" do
      err = described_class.from_response({
        "kind" => "NotAllowed",
        "message" => "access denied"
      })
      expect(err).to be_a(SurrealDB::NotAllowedError)
    end

    it "maps Query kind to QueryError" do
      err = described_class.from_response({
        "kind" => "Query",
        "message" => "query timeout"
      })
      expect(err).to be_a(SurrealDB::QueryError)
    end

    it "maps AlreadyExists kind" do
      err = described_class.from_response({
        "kind" => "AlreadyExists",
        "message" => "record exists"
      })
      expect(err).to be_a(SurrealDB::AlreadyExistsError)
    end

    it "maps Validation kind" do
      err = described_class.from_response({
        "kind" => "Validation",
        "message" => "invalid input"
      })
      expect(err).to be_a(SurrealDB::ValidationError)
    end

    it "falls back to ServerError for unknown kinds" do
      err = described_class.from_response({
        "kind" => "SomeFutureKind",
        "message" => "unknown"
      })
      expect(err).to be_a(SurrealDB::ServerError)
      expect(err).not_to be_a(SurrealDB::QueryError)
    end

    it "parses cause chains" do
      err = described_class.from_response({
        "kind" => "Query",
        "message" => "outer",
        "cause" => {
          "kind" => "NotFound",
          "message" => "inner"
        }
      })
      expect(err).to be_a(SurrealDB::QueryError)
      expect(err.server_cause).to be_a(SurrealDB::NotFoundError)
      expect(err.server_cause.message).to eq("inner")
    end

    it "stores details" do
      err = described_class.from_response({
        "kind" => "NotAllowed",
        "message" => "denied",
        "details" => { "kind" => "TokenExpired" }
      })
      expect(err.details).to eq({ "kind" => "TokenExpired" })
    end
  end

  describe "#find_cause" do
    it "finds a cause by kind" do
      err = described_class.from_response({
        "kind" => "Query",
        "message" => "outer",
        "cause" => {
          "kind" => "NotFound",
          "message" => "inner"
        }
      })
      found = err.find_cause("NotFound")
      expect(found).to be_a(SurrealDB::NotFoundError)
    end

    it "returns nil when kind not in chain" do
      err = described_class.from_response({
        "kind" => "Query",
        "message" => "outer"
      })
      expect(err.find_cause("NotFound")).to be_nil
    end

    it "finds self if matching" do
      err = described_class.from_response({
        "kind" => "NotFound",
        "message" => "direct"
      })
      expect(err.find_cause("NotFound")).to eq(err)
    end
  end

  describe "#has_kind?" do
    it "returns true when kind exists in chain" do
      err = described_class.from_response({
        "kind" => "Query",
        "message" => "outer",
        "cause" => { "kind" => "NotFound", "message" => "inner" }
      })
      expect(err.has_kind?("NotFound")).to be true
      expect(err.has_kind?("AlreadyExists")).to be false
    end
  end
end

RSpec.describe SurrealDB::Protocol::Response do
  describe ".extract_result" do
    it "returns the result value" do
      result = described_class.extract_result({ "id" => 1, "result" => "ok" })
      expect(result).to eq("ok")
    end

    it "raises ServerError on error response" do
      expect do
        described_class.extract_result({
          "id" => 1,
          "error" => { "code" => -1, "message" => "fail" }
        })
      end.to raise_error(SurrealDB::ServerError, "fail")
    end

    it "raises ProtocolError on malformed response" do
      expect do
        described_class.extract_result("not a hash")
      end.to raise_error(SurrealDB::ProtocolError)
    end

    it "raises ProtocolError when both keys missing" do
      expect do
        described_class.extract_result({ "id" => 1 })
      end.to raise_error(SurrealDB::ProtocolError)
    end
  end
end
