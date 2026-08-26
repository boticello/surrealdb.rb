# frozen_string_literal: true

module SurrealDB
  # A GeoJSON Point with longitude and latitude coordinates.
  #
  # @example
  #   point = SurrealDB::GeometryPoint.new(-122.4194, 37.7749)
  #   point.longitude  # => -122.4194
  #   point.coordinates  # => [-122.4194, 37.7749]
  class GeometryPoint
    # @return [Float] longitude (x-axis)
    attr_reader :longitude

    # @return [Float] latitude (y-axis)
    attr_reader :latitude

    # @param longitude [Numeric]
    # @param latitude [Numeric]
    def initialize(longitude, latitude)
      @longitude = longitude.to_f
      @latitude = latitude.to_f
    end

    # @return [Array<Float>] [longitude, latitude]
    def coordinates
      [@longitude, @latitude]
    end

    def ==(other)
      other.is_a?(GeometryPoint) && other.longitude == @longitude && other.latitude == @latitude
    end
    alias eql? ==

    def hash
      [self.class, @longitude, @latitude].hash
    end

    def inspect
      "GeometryPoint(#{@longitude}, #{@latitude})"
    end
  end

  # A GeoJSON LineString defined by two or more points.
  #
  # @example
  #   line = SurrealDB::GeometryLine.new(point1, point2, point3)
  #   line.points.length  # => 3
  class GeometryLine
    # @return [Array<GeometryPoint>] ordered points defining the line
    attr_reader :points

    # @param points [Array<GeometryPoint>] at least two points
    # @raise [ArgumentError] if fewer than two points are provided
    def initialize(*points)
      raise ArgumentError, 'a line requires at least 2 points' if points.length < 2

      @points = points.freeze
    end

    # @return [Array<Array<Float>>] array of [longitude, latitude] pairs
    def coordinates
      @points.map(&:coordinates)
    end

    def ==(other)
      other.is_a?(GeometryLine) && other.points == @points
    end
    alias eql? ==

    def hash
      [self.class, @points].hash
    end

    def inspect
      "GeometryLine(#{@points.length} points)"
    end
  end

  # A GeoJSON Polygon with an exterior ring and optional interior holes.
  #
  # @example
  #   polygon = SurrealDB::GeometryPolygon.new(exterior_ring)
  #   polygon_with_hole = SurrealDB::GeometryPolygon.new(exterior_ring, hole_ring)
  class GeometryPolygon
    # @return [GeometryLine] exterior ring
    attr_reader :exterior

    # @return [Array<GeometryLine>] interior rings (holes), may be empty
    attr_reader :interiors

    # @param exterior [GeometryLine] the outer ring
    # @param interiors [Array<GeometryLine>] optional interior rings (holes)
    def initialize(exterior, *interiors)
      @exterior = exterior
      @interiors = interiors.freeze
    end

    def ==(other)
      other.is_a?(GeometryPolygon) && other.exterior == @exterior && other.interiors == @interiors
    end
    alias eql? ==

    def hash
      [self.class, @exterior, @interiors].hash
    end

    def inspect
      "GeometryPolygon(exterior: #{@exterior.points.length} points, holes: #{@interiors.length})"
    end
  end

  # A GeoJSON MultiPoint collection.
  #
  # @example
  #   multi = SurrealDB::GeometryMultiPoint.new(point1, point2)
  class GeometryMultiPoint
    # @return [Array<GeometryPoint>]
    attr_reader :points

    # @param points [Array<GeometryPoint>]
    def initialize(*points)
      @points = points.freeze
    end

    def ==(other)
      other.is_a?(GeometryMultiPoint) && other.points == @points
    end
    alias eql? ==

    def hash
      [self.class, @points].hash
    end
  end

  # A GeoJSON MultiLineString collection.
  #
  # @example
  #   multi = SurrealDB::GeometryMultiLine.new(line1, line2)
  class GeometryMultiLine
    # @return [Array<GeometryLine>]
    attr_reader :lines

    # @param lines [Array<GeometryLine>]
    def initialize(*lines)
      @lines = lines.freeze
    end

    def ==(other)
      other.is_a?(GeometryMultiLine) && other.lines == @lines
    end
    alias eql? ==

    def hash
      [self.class, @lines].hash
    end
  end

  # A GeoJSON MultiPolygon collection.
  #
  # @example
  #   multi = SurrealDB::GeometryMultiPolygon.new(polygon1, polygon2)
  class GeometryMultiPolygon
    # @return [Array<GeometryPolygon>]
    attr_reader :polygons

    # @param polygons [Array<GeometryPolygon>]
    def initialize(*polygons)
      @polygons = polygons.freeze
    end

    def ==(other)
      other.is_a?(GeometryMultiPolygon) && other.polygons == @polygons
    end
    alias eql? ==

    def hash
      [self.class, @polygons].hash
    end
  end

  # A GeoJSON GeometryCollection containing heterogeneous geometry types.
  #
  # @example
  #   collection = SurrealDB::GeometryCollection.new(point, line, polygon)
  class GeometryCollection
    # @return [Array<GeometryPoint, GeometryLine, GeometryPolygon,
    #   GeometryMultiPoint, GeometryMultiLine, GeometryMultiPolygon>]
    attr_reader :geometries

    # @param geometries [Array<GeometryPoint, GeometryLine, GeometryPolygon,
    #   GeometryMultiPoint, GeometryMultiLine, GeometryMultiPolygon>]
    def initialize(*geometries)
      @geometries = geometries.freeze
    end

    def ==(other)
      other.is_a?(GeometryCollection) && other.geometries == @geometries
    end
    alias eql? ==

    def hash
      [self.class, @geometries].hash
    end
  end
end
