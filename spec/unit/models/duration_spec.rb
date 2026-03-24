# frozen_string_literal: true

RSpec.describe SurrealDB::Duration do
  describe ".new" do
    it "stores seconds and nanos" do
      d = described_class.new(10, 500_000_000)
      expect(d.secs).to eq(10)
      expect(d.nanos).to eq(500_000_000)
    end

    it "normalizes overflow nanos" do
      d = described_class.new(0, 2_500_000_000)
      expect(d.secs).to eq(2)
      expect(d.nanos).to eq(500_000_000)
    end
  end

  describe ".parse" do
    it "parses seconds" do
      d = described_class.parse("30s")
      expect(d.secs).to eq(30)
      expect(d.nanos).to eq(0)
    end

    it "parses compound durations" do
      d = described_class.parse("1h30m")
      expect(d.secs).to eq(5400)
    end

    it "parses days and hours" do
      d = described_class.parse("2d3h")
      expect(d.secs).to eq(2 * 86_400 + 3 * 3600)
    end

    it "parses milliseconds" do
      d = described_class.parse("500ms")
      expect(d.secs).to eq(0)
      expect(d.nanos).to eq(500_000_000)
    end

    it "parses microseconds" do
      d = described_class.parse("100us")
      expect(d.nanos).to eq(100_000)
    end

    it "parses nanoseconds" do
      d = described_class.parse("42ns")
      expect(d.nanos).to eq(42)
    end

    it "parses weeks" do
      d = described_class.parse("1w")
      expect(d.secs).to eq(7 * 86_400)
    end

    it "parses years" do
      d = described_class.parse("1y")
      expect(d.secs).to eq(365 * 86_400)
    end

    it "rejects invalid strings" do
      expect { described_class.parse("invalid") }.to raise_error(ArgumentError)
    end
  end

  describe "#to_s" do
    it "formats zero duration" do
      expect(described_class.new(0, 0).to_s).to eq("0s")
    end

    it "formats simple seconds" do
      expect(described_class.new(30, 0).to_s).to eq("30s")
    end

    it "formats compound durations" do
      expect(described_class.new(5400, 0).to_s).to eq("1h30m")
    end

    it "formats milliseconds" do
      expect(described_class.new(0, 500_000_000).to_s).to eq("500ms")
    end
  end

  describe "#to_f" do
    it "returns total seconds as float" do
      d = described_class.new(10, 500_000_000)
      expect(d.to_f).to be_within(0.001).of(10.5)
    end
  end

  describe "equality" do
    it "considers equal durations as equal" do
      a = described_class.new(10, 500)
      b = described_class.new(10, 500)
      expect(a).to eq(b)
    end
  end
end
