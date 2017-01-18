module Dokumi
  module Support
    module Shell
      def self.with_clean_env(&block)
        to_run = lambda do
          saved_version = ENV["RBENV_VERSION"]
          begin
            ENV["RBENV_VERSION"] = nil
            block.call
          ensure
            ENV["RBENV_VERSION"] = saved_version
          end
        end
        if defined?(Bundler)
          Bundler.with_clean_env(&to_run)
        else
          to_run.call
        end
      end

      def self.using_rbenv?
        ENV.keys.any? {|key| key.start_with?("RBENV_") }
      end

      def self.stringify_shell_arguments(args)
        # We do not want to stringify everything. For example, hashes (used to pass the environment) should stay as is.
        args.map {|arg| (arg.is_a?(Pathname) or arg.is_a?(Symbol)) ? arg.to_s : arg }
      end

      def self.prepare_arguments(args)
        args = stringify_shell_arguments(args)

        return args unless using_rbenv?

        commands_needing_override = ["bundle", "ruby"]
        env = nil
        if args.first.respond_to?(:to_hash)
          env = args.shift
        end

        if args.length == 1 and commands_needing_override.include?(args.first.strip.split(/\s+/).first)
          args = ["rbenv exec #{args.first}"]
        elsif commands_needing_override.include?(args.first)
          args = ["rbenv", "exec", *args]
        end

        if env
          [env, *args]
        else
          args
        end
      end

      def self.popen_each_line(*args)
        options = Support.extract_options!(args)
        Support.validate_hash options, only: [:allow_errors, :silent]
        original_args = stringify_shell_arguments(args)
        args = prepare_arguments(args)
        Support.logger.debug "reading outputs of #{original_args.inspect}"
        exit_status = nil
        Support.benchmarker.measure(*original_args) do
          with_clean_env do
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
        end
        exit_code = exit_status.exitstatus
        raise "#{args.inspect} exited in error: #{exit_status.inspect}" if exit_code != 0 and !options[:allow_errors]
        exit_code
      end

      def self.run(*args)
        options = Support.extract_options!(args)
        Support.validate_hash options, only: [:allow_errors, :silent]
        original_args = stringify_shell_arguments(args)
        args = prepare_arguments(args)
        Support.logger.debug "running #{original_args.inspect}"
        Support.benchmarker.measure(*original_args) do
          with_clean_env do
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
