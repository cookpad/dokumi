require_relative "android/findbugs"

module Dokumi
  module Tool
    class Android
      def initialize(environment)
        @environment = environment
        @configuration = read_configuration
      end

      def gradle(*args)
        Support::Shell.run({"ANDROID_HOME" => @configuration[:android_home]}, "./gradlew", *args)
      end

      def findbugs(target_project)
        @environment.action_executed = true

        gradle "--stacktrace", "findbugs"
        FindBugs.parse_report(target_project).each do |bug|
          @environment.add_issue(
              file_path: bug[:file_path],
              line: bug[:line],
              type: bug[:type],
              description: bug[:description],
              tool: :findbugs,
          )
        end
      end

      def infer(target_project)
        @environment.action_executed = true

        Support::Shell.run({"ANDROID_HOME" => @configuration[:android_home]}, "infer", "--", "./gradlew", "build")
        Infer.parse_report(target_project).each do |bug|
          @environment.add_issue(
              file_path: bug[:file_path],
              line: bug[:line],
              type: :static_analysis,
              description: bug[:description],
          )
        end
      end

      private

      def read_configuration
        configuration_path = BASE_DIRECTORY.join("config", "android.yml")
        configuration = Support.symbolize_keys YAML.load(IO.read(configuration_path))
        Support.validate_hash configuration, requires_only: [:android_home]
        configuration
      end
    end
  end
end
