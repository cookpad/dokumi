require 'benchmark'
require 'json'

module Dokumi
  module Support
    class ExecutionLog
      attr_reader :command, :tms, :start_time

      def initialize(command, tms, start_time)
        @command = command
        @tms = tms
        @start_time = start_time
      end

      def to_hash
        { command: command,
          cstime: tms.cstime,
          cutime: tms.cutime,
          real: tms.real,
          stime: tms.stime,
          total: tms.total,
          utime: tms.utime,
          start_time: start_time.to_i,
        }
      end
    end

    class Benchmarker
      def initialize
        @data = []
      end

      def export!(filename)
        json = JSON.pretty_generate(data.map(&:to_hash))
        File.write(filename, json)
        Support.logger.info "#{filename} has been exported"
      end

      def measure(*args, &block)
        command = args.map {|arg| arg.to_s.shellescape }
        start_time = Time.now
        tms = Benchmark.measure(command, &block)
        data << ExecutionLog.new(command, tms, start_time)
      end

      private
      attr_accessor :data
    end

    def self.benchmarker
      @benchmarker ||= Benchmarker.new
    end
  end
end
