module Dokumi
  module Support
    class MultiLogger
      def initialize(*loggers)
        @loggers = loggers.flatten
      end

      [
        :debug,
        :info,
        :warn,
        :error,
        :fatal,
      ].each do |method_name|
        define_method(method_name) do |*args|
          @loggers.each do |logger|
            logger.send(method_name, *args)
          end
        end
      end
    end

    def self.logger
      return @logger if @logger
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::INFO
      @logger
    end

    def self.logger=(logger)
      @logger = logger
    end
  end
end
