module Dokumi
  module Support
    module Shell
      def self.with_clean_env(&block)
        if defined?(Bundler)
          Bundler.with_clean_env(&block)
        else
          block.call
        end
      end

      def self.stringify_shell_arguments(args)
        # We do not want to stringify everything. For example, hashes (used to pass the environment) should stay as is.
        args.map {|arg| (arg.is_a?(Pathname) or arg.is_a?(Symbol)) ? arg.to_s : arg }
      end

      def self.popen_each_line(*args)
        options = Support.extract_options!(args)
        Support.validate_hash options, only: [:allow_errors, :silent]
        args = stringify_shell_arguments(args)
        Support.logger.debug "reading outputs of #{args.inspect}"
        exit_status = nil
        with_clean_env do
          Support.benchmarker.measure(args.join(' ')) do
            exit_status = Open3.popen3(*args) do |stdin, stdout, stderr, wait_thread|
              stdin.close
              to_read = [stdout, stderr]
              until to_read.empty?
                available, _, _ = IO.select(to_read)
                while io = available.pop
                  if io.eof?
                    io.close
                    to_read.delete io
                    next
                  end
                  case io
                    when stderr
                      yield :error, io.gets
                    when stdout
                      yield :output, io.gets
                  end
                end
              end
              wait_thread.value
            end
          end
          exit_code = exit_status.exitstatus
          raise "#{args.inspect} exited in error: #{exit_status.inspect}" if exit_code != 0 and !options[:allow_errors]
          exit_code
        end
      end

      def self.run(*args)
        options = Support.extract_options!(args)
        Support.validate_hash options, only: [:allow_errors, :silent]
        args = stringify_shell_arguments(args)
        Support.logger.debug "running #{args.inspect}"
        with_clean_env do
          Support.benchmarker.measure(args.join(' ')) do
            system(*args)
          end
        end
        exit_status = $?
        exit_code = exit_status.exitstatus
        raise "#{args.inspect} exited in error: #{exit_status.inspect}" if exit_code != 0 and !options[:allow_errors]
        exit_code
      end

      def self.quit_osx_application(application_name)
        exit_code = run("osascript", "-e", %{quit app "#{application_name}"}, allow_errors: true)
        run "killall", application_name, allow_errors: true unless exit_code == 0
      end
    end
  end
end
