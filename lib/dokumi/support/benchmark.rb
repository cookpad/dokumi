require 'benchmark'
require 'json'

module Dokumi
  module Support
    class Benchmarker
      attr_accessor :data

      def initialize
        @data = {}
      end

      def export!(filename)
        output = @data.map do |command, tms|
          {
            command: command,
            cstime: tms.cstime,
            cutime: tms.cutime,
            real: tms.real,
            stime: tms.stime,
            total: tms.total,
            utime: tms.utime
          }
        end
        File.open(filename, 'w') do |file|
          JSON.dump(output, file)
        end
        Support.logger.info "#{filename} is exported"
      end
    end

    def self.measure(label)
      tms = Benchmark.measure(label) do
        yield
      end
      benchmarker.data[label] = tms
    end

    private
    def self.benchmarker
      return @benchmarker if @benchmarker
      @benchmarker = Benchmarker.new
    end
  end
end
