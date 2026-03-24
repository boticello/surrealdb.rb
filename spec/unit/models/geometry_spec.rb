# frozen_string_literal: true

RSpec.describe SurrealDB::GeometryPoint do
  it 'stores longitude and latitude' do
    p = described_class.new(-122.4194, 37.7749)
    expect(p.longitude).to eq(-122.4194)
    expect(p.latitude).to eq(37.7749)
  end

  it 'returns coordinates as array' do
    p = described_class.new(1.0, 2.0)
    expect(p.coordinates).to eq([1.0, 2.0])
  end

  it 'supports equality' do
    a = described_class.new(1.0, 2.0)
    b = described_class.new(1.0, 2.0)
    expect(a).to eq(b)
  end
end

RSpec.describe SurrealDB::GeometryLine do
  let(:origin) { SurrealDB::GeometryPoint.new(0.0, 0.0) }
  let(:diagonal) { SurrealDB::GeometryPoint.new(1.0, 1.0) }
  let(:far_point) { SurrealDB::GeometryPoint.new(2.0, 0.0) }

  it 'requires at least 2 points' do
    expect { described_class.new(origin) }.to raise_error(ArgumentError)
  end

  it 'stores points' do
    line = described_class.new(origin, diagonal, far_point)
    expect(line.points.length).to eq(3)
  end

  it 'returns coordinates' do
    line = described_class.new(origin, diagonal)
    expect(line.coordinates).to eq([[0.0, 0.0], [1.0, 1.0]])
  end
end

RSpec.describe SurrealDB::GeometryPolygon do
  let(:exterior) do
    SurrealDB::GeometryLine.new(
      SurrealDB::GeometryPoint.new(0.0, 0.0),
      SurrealDB::GeometryPoint.new(1.0, 0.0),
      SurrealDB::GeometryPoint.new(1.0, 1.0),
      SurrealDB::GeometryPoint.new(0.0, 0.0)
    )
  end

  it 'stores exterior ring' do
    polygon = described_class.new(exterior)
    expect(polygon.exterior).to eq(exterior)
    expect(polygon.interiors).to be_empty
  end

  it 'stores interior rings' do
    hole = SurrealDB::GeometryLine.new(
      SurrealDB::GeometryPoint.new(0.2, 0.2),
      SurrealDB::GeometryPoint.new(0.8, 0.2),
      SurrealDB::GeometryPoint.new(0.2, 0.2)
    )
    polygon = described_class.new(exterior, hole)
    expect(polygon.interiors.length).to eq(1)
  end
end

RSpec.describe SurrealDB::GeometryCollection do
  it 'stores mixed geometry types' do
    point = SurrealDB::GeometryPoint.new(1.0, 2.0)
    line = SurrealDB::GeometryLine.new(
      SurrealDB::GeometryPoint.new(0.0, 0.0),
      SurrealDB::GeometryPoint.new(1.0, 1.0)
    )
    collection = described_class.new(point, line)
    expect(collection.geometries.length).to eq(2)
  end
end
