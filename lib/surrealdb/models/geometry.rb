# frozen_string_literal: true

module SurrealDB
  class GeometryPoint
    attr_reader :longitude, :latitude

    def initialize(longitude, latitude)
      @longitude = longitude.to_f
      @latitude = latitude.to_f
    end

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

  class GeometryLine
    # @return [Array<GeometryPoint>]
    attr_reader :points

    def initialize(*points)
      raise ArgumentError, 'a line requires at least 2 points' if points.length < 2

      @points = points.freeze
    end

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

  class GeometryPolygon
    # @return [GeometryLine] exterior ring
    attr_reader :exterior

    # @return [Array<GeometryLine>] interior rings (holes)
    attr_reader :interiors

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

  class GeometryMultiPoint
    attr_reader :points

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

  class GeometryMultiLine
    attr_reader :lines

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

  class GeometryMultiPolygon
    attr_reader :polygons

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

  class GeometryCollection
    attr_reader :geometries

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
