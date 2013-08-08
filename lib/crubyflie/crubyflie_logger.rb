# This module is included where needed and offers
# easy access to the logger
module Logging
    # Give me a logger
    # @return [CrubyflieLogger]
    def self.logger
        Logging.logger
    end

    # Lazy initialization for a logger
    # @return [CrubyflieLogger]
    def logger
        @logger ||= CrubyflieLogger.new()
    end

    # Set a logger
    # @param logger [CrubyflieLogger] the new logger to use
    def logger=(logger)
        @logger = logger
    end
end

# A simple logger to log debug messages, info, warnings and errors
class CrubyflieLogger
    # Initialize a logger and enable debug logs
    # @param debug [TrueClass,nil] enable output of debug messages
    def initialize(debug=$debug)
        @@debug = debug
    end

    # Logs a debug message
    # @param msg [String] the message to be logged
    def debug(msg)
        $stderr.puts "DEBUG: #{msg}" if @@debug
    end

    # Logs an info message to $stdout
    # @param msg [String] the message to be logged
    def info(msg)
        $stdout.puts "INFO: #{msg}"
    end

    # Logs a warning message to $stderr
    # @param msg [String] the message to be logged
    def warn(msg)
        $stderr.puts "WARNING: #{msg}"
    end

    # Logs an error message to $stderr
    # @param msg [String] the message to be logged
    def error(msg)
        $stderr.puts "ERROR: #{msg}"
    end
end
