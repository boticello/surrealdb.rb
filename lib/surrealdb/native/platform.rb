# frozen_string_literal: true

module SurrealDB
  module Native
    # Resolves the platform-specific path to the libsurrealdb_c shared library.
    module Platform
      module_function

      # @return [String] absolute path or library name for FFI.ffi_lib
      # @raise [LoadError] if the library cannot be found
      def library_path
        from_env || from_system
      end

      # @return [String] shared library file extension for the current OS
      def library_extension
        case host_os
        when :macos   then 'dylib'
        when :windows then 'dll'
        else 'so'
        end
      end

      # @return [String] expected library filename
      def library_name
        case host_os
        when :windows then 'surrealdb_c.dll'
        else "libsurrealdb_c.#{library_extension}"
        end
      end

      # @return [Symbol] :linux, :macos, or :windows
      def host_os
        case RbConfig::CONFIG['host_os']
        when /darwin/i then :macos
        when /mingw|mswin|cygwin/i then :windows
        else :linux
        end
      end

      # @return [Symbol] :x86_64 or :aarch64
      def host_cpu
        case RbConfig::CONFIG['host_cpu']
        when /x86_64|amd64/i then :x86_64
        when /aarch64|arm64/i then :aarch64
        else RbConfig::CONFIG['host_cpu'].to_sym
        end
      end

      def from_env
        path = ENV.fetch('SURREALDB_LIB_PATH', nil)
        return nil if path.nil? || path.empty?
        raise LoadError, "SURREALDB_LIB_PATH points to missing file: #{path}" unless File.exist?(path)

        path
      end

      def from_system
        library_name
      end

      private_class_method :from_env, :from_system
    end
  end
end
