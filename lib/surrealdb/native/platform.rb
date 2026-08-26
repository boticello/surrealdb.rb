# frozen_string_literal: true

module SurrealDB
  module Native
    # Resolves the platform-specific path to the libsurrealdb_c shared library.
    module Platform
      SUPPORTED_CPUS = {
        linux: %i[aarch64 x86_64],
        macos: %i[aarch64 x86_64],
        windows: [:x86_64]
      }.freeze

      module_function

      # @return [String] absolute path or library name for FFI.ffi_lib
      # @raise [LoadError] if the library cannot be found
      def library_path
        validate_platform!
        from_env || from_system
      end

      # @return [String] normalized OS/libc/CPU label
      def platform_label
        validate_platform!

        case host_os
        when :linux then "linux-#{host_libc}-#{host_cpu}"
        else "#{host_os}-#{host_cpu}"
        end
      end

      # @raise [LoadError] if libsurrealdb_c is not supported on this host
      def validate_platform!
        supported_cpus = SUPPORTED_CPUS.fetch(host_os, [])
        return true if supported_cpus.include?(host_cpu)

        raise LoadError,
              "unsupported platform: #{raw_host_os} on #{raw_host_cpu}; " \
              'supported platforms are macOS and Linux on arm64/x86_64, and Windows on x86_64'
      end

      # @param cause [Exception]
      # @return [String]
      def load_error_message(cause)
        "unable to load #{library_name} for #{platform_label}. " \
          'Install libsurrealdb_c in the system library path or set SURREALDB_LIB_PATH ' \
          "to the library file or its directory. Original error: #{cause.message}"
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
        case raw_host_os
        when /darwin/i then :macos
        when /mingw|mswin|cygwin/i then :windows
        when /linux/i then :linux
        else :unsupported
        end
      end

      # @return [Symbol] :x86_64 or :aarch64
      def host_cpu
        case raw_host_cpu
        when /x86_64|amd64/i then :x86_64
        when /aarch64|arm64/i then :aarch64
        else raw_host_cpu.to_sym
        end
      end

      # @return [Symbol] :glibc or :musl
      def host_libc
        platform_data = [raw_host_os, RbConfig::CONFIG['arch'], RUBY_PLATFORM].join('-')
        platform_data.match?(/musl/i) ? :musl : :glibc
      end

      def from_env
        path = ENV.fetch('SURREALDB_LIB_PATH', nil)
        return nil if path.nil? || path.empty?

        candidate = File.directory?(path) ? File.join(path, library_name) : path
        raise LoadError, "SURREALDB_LIB_PATH points to missing library file: #{candidate}" unless File.file?(candidate)

        File.expand_path(candidate)
      end

      def from_system
        library_name
      end

      def raw_host_os
        RbConfig::CONFIG['host_os'].to_s
      end

      def raw_host_cpu
        RbConfig::CONFIG['host_cpu'].to_s
      end

      private_class_method :from_env, :from_system, :raw_host_os, :raw_host_cpu
    end
  end
end
