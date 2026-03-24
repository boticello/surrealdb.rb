# frozen_string_literal: true

RSpec.describe SurrealDB::CBOR::Encoder do
  describe ".prepare" do
    it "converts None to tagged value" do
      result = described_class.prepare(SurrealDB::NONE)
      expect(result).to be_a(::CBOR::Tagged)
      expect(result.tag).to eq(SurrealDB::CBOR::Tags::NONE)
    end

    it "converts Table to tagged value" do
      result = described_class.prepare(SurrealDB::Table.new("users"))
      expect(result).to be_a(::CBOR::Tagged)
      expect(result.tag).to eq(SurrealDB::CBOR::Tags::TABLE)
      expect(result.value).to eq("users")
    end

    it "converts RecordID to tagged value" do
      result = described_class.prepare(SurrealDB::RecordID.new("user", "john"))
      expect(result).to be_a(::CBOR::Tagged)
      expect(result.tag).to eq(SurrealDB::CBOR::Tags::RECORD_ID)
      expect(result.value).to eq(["user", "john"])
    end

    it "converts Duration to tagged value" do
      result = described_class.prepare(SurrealDB::Duration.new(10, 500))
      expect(result).to be_a(::CBOR::Tagged)
      expect(result.tag).to eq(SurrealDB::CBOR::Tags::DURATION_COMPACT)
      expect(result.value).to eq([10, 500])
    end

    it "converts Time to tagged datetime" do
      t = Time.utc(2024, 1, 15, 12, 0, 0)
      result = described_class.prepare(t)
      expect(result).to be_a(::CBOR::Tagged)
      expect(result.tag).to eq(SurrealDB::CBOR::Tags::DATETIME_COMPACT)
      expect(result.value[0]).to eq(t.to_i)
    end

    it "converts BigDecimal to tagged decimal string" do
      result = described_class.prepare(BigDecimal("3.14"))
      expect(result).to be_a(::CBOR::Tagged)
      expect(result.tag).to eq(SurrealDB::CBOR::Tags::DECIMAL_STRING)
      expect(result.value).to eq("3.14")
    end

    it "converts Range with bounds" do
      range = SurrealDB::Range.new(
        SurrealDB::BoundIncluded.new(1),
        SurrealDB::BoundExcluded.new(10)
      )
      result = described_class.prepare(range)
      expect(result.tag).to eq(SurrealDB::CBOR::Tags::RANGE)
    end

    it "converts GeometryPoint" do
      result = described_class.prepare(SurrealDB::GeometryPoint.new(1.0, 2.0))
      expect(result.tag).to eq(SurrealDB::CBOR::Tags::GEOMETRY_POINT)
      expect(result.value).to eq([1.0, 2.0])
    end

    it "recursively converts hashes" do
      result = described_class.prepare({ "table" => SurrealDB::Table.new("x") })
      expect(result["table"]).to be_a(::CBOR::Tagged)
    end

    it "recursively converts arrays" do
      result = described_class.prepare([SurrealDB::Table.new("x")])
      expect(result[0]).to be_a(::CBOR::Tagged)
    end

    it "passes through primitives unchanged" do
      expect(described_class.prepare("hello")).to eq("hello")
      expect(described_class.prepare(42)).to eq(42)
      expect(described_class.prepare(true)).to eq(true)
      expect(described_class.prepare(nil)).to be_nil
    end
  end

  describe ".encode" do
    it "returns a binary string" do
      result = described_class.encode("hello")
      expect(result).to be_a(String)
      expect(result.encoding).to eq(Encoding::BINARY)
    end
  end
end
