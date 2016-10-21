require 'benchmark'
require 'json'

module Dokumi
  module Support
    class ExecutionLog
      attr_reader :command, :tms, :timestamp

      def initialize(command, tms, timestamp)
        @command = command
        @tms = tms
        @timestamp = timestamp
      end

      def to_hash
        { command: command,
          cstime: tms.cstime,
          cutime: tms.cutime,
          real: tms.real,
          stime: tms.stime,
          total: tms.total,
          utime: tms.utime,
          timestamp: timestamp.to_i,
        }
      end
    end


    class Benchmarker
      def initialize
        @data = []
      end

      def export!(filename)
        File.open(filename, 'w') do |file|
          JSON.dump(data.map(&:to_hash), file)
        end
        Support.logger.info "#{filename} is exported"
      end

      def measure(command)
        timestamp = Time.now
        tms = Benchmark.measure(command) do
          yield
        end
        data << ExecutionLog.new(command, tms, timestamp)
      end

      private
      attr_accessor :data
    end

    private
    def self.benchmarker
      return @benchmarker if @benchmarker
      @benchmarker = Benchmarker.new
    end
  end
end
