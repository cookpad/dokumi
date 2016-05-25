require_relative "xcode/project_helper"
require_relative "xcode/unchanged_storyboard_finder"
require_relative "xcode/misplaced_constraint_finder"
require_relative "xcode/error_extractor"
require_relative "xcode/project_checker"

module Dokumi
  module Tool
    class Xcode
      def initialize(environment)
        @environment = environment
        @xcode_version = :default
      end

      def use_xcode_version(version)
        version = version.to_s
        version = :default if version == "default"
        configuration = self.class.read_configuration
        raise "Xcode version #{version} is not configured in xcode_versions.yml" unless configuration[version]
        @xcode_version = version
      end

      def require_warnings(xcodeproj_path, *warnings)
        @environment.action_executed = true
        Xcode::ProjectChecker.new(@environment, xcodeproj_path).require_warnings(*warnings)
      end

      def modify_project(xcodeproj_path)
        yield Xcode::ProjectHelper.new(xcodeproj_path)
      end

      def icon_paths_in_project(xcodeproj_path)
        Xcode::ProjectHelper.new(xcodeproj_path).icon_paths
      end

      def analyze(project_path, options)
        Support.validate_hash options, requires_only: :scheme
        @environment.action_executed = true

        xcodebuild project_path, actions: :analyze, scheme: options[:scheme], sdk: "iphoneos"

        project_basename = File.basename(project_path, File.extname(project_path))
        static_analyzer_plist_pattern = @environment.work_directory.join(
          "Build",
          "Intermediates",
          "#{project_basename}.build",
          "**",
          "StaticAnalyzer",
          "**",
          "*.plist"
        )
        Dir.glob(static_analyzer_plist_pattern).each do |plist_path|
          content = Xcodeproj::Plist.read_from_path(plist_path)
          next unless content["clang_version"] and content["files"] and content["diagnostics"]
          next if content["files"].empty? or content["diagnostics"].empty?
          content["diagnostics"].each do |diagnostic|
            location = diagnostic["location"]
            @environment.add_issue(
              file_path: content["files"][location["file"]],
              line: location["line"].to_i,
              column: location["col"].to_i,
              type: :warning,
              tool: :static_analyzer,
              description: diagnostic["description"],
            )
          end
        end
      end

      def test(project_path, options)
        Support.validate_hash options, requires_only: [:scheme, :destination]
        @environment.action_executed = true

        [ options[:destination] ].flatten.each do |destination|
          xcodebuild project_path, actions: :test, scheme: options[:scheme], sdk: "iphonesimulator", destination: destination
        end
      end

      def archive(project_path, options)
        Support.validate_hash options, requires_only: :scheme
        @environment.action_executed = true

        project_basename = File.basename(project_path, File.extname(project_path))
        archive_path = @environment.work_directory.join("#{project_basename}.xcarchive")
        ipa_path = @environment.work_directory.join("#{project_basename}.ipa")

        xcodebuild project_path, actions: :archive, scheme: options[:scheme], sdk: "iphoneos", archive_path: archive_path
        raise "an error was found while build the archive" if @environment.error_found?

        # As xcodebuild -exportArchive doesn't seem to work properly with WatchKit apps, I ended up making the IPA file by hand.
        # https://devforums.apple.com/message/1120211#1120211 has some information about doing that:
        # If you are building your final product outside of Xcode (or have interesting build scripts), before zipping contents to create the IPA, you should:
        # 1. Create a directory named WatchKitSupport as a sibling to Payload.
        # 2. Copy a binary named "WK" from the iOS 8.2 SDK in Xcode to your new WatchKitSupport directory. This binary can be found at:
        #  /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/Library/Application Support/WatchKit/
        # 3. Make sure the "WK" binary is not touched/re-signed in any way. This is important for validation on device.
        # 4. Zip everything into an IPA.
        #
        # When expanded the IPA should contain (at least):
        # xxx.ipa
        # |________Payload/
        # |________Symbols/
        # |________WatchKitSupport/
        #                    |_____WK
        # That should help when building.
        directory_for_archiving = @environment.work_directory.join("archiving")
        directory_for_archiving.mkpath
        Dir.chdir(directory_for_archiving) do
          # we are creating symbolic links, but in the zip (ipa) they will be stored as normal directories (and that's what we want)
          FileUtils.ln_s archive_path.join("Products", "Applications"), "Payload"
          ["WatchKitSupport", "SwiftSupport"].each do |support_type|
            support_source_path = archive_path.join(support_type)
            FileUtils.ln_s support_source_path, support_source_path.basename if support_source_path.exist?
          end

          Support::Shell.run "zip", "-r", ipa_path, "."
          @environment.add_artifacts ipa_path
        end

        to_archive = archive_path.join("dSYMs").children + archive_path.join("Products", "Applications").children
        to_archive.select! {|path| [ ".app", ".dSYM" ].include?(path.extname) }
        to_archive.each do |path|
          Dir.chdir path.dirname do
            zip_path = @environment.work_directory.join("#{path.basename}.zip")
            Support::Shell.run "zip", "-r", zip_path, path.basename
            @environment.add_artifacts zip_path
          end
        end

      end

      IGNORED_COCOAPODS_WARNINGS = [
        "Please close any current Xcode sessions", # .xcworkspace file generated.
        "This is a test version", # Newer version of CocoaPods available.
        "Unable to load a specification for the plugin", # CocoaPods tries to load plugins that might not be compatible with the version used.
      ]
      def install_pods
        raise "does not use CocoaPods" unless File.exist?("Podfile")
        if File.exist?("Gemfile")
          Support::Shell.run "bundle", "install"
          pod_command = ["bundle", "exec", "pod"]
        elsif File.exist?("Podfile.lock")
          cocoapods_version = YAML.load(IO.read("Podfile.lock"))["COCOAPODS"]
          pod_command = ["pod", "_#{cocoapods_version}_"]
        else
          pod_command = ["pod"]
        end
        first_try = true
        loop do
          warnings_found = {output: [], error: []}
          warning_not_finished = {output: false, error: false}
          exit_code = Support::Shell.popen_each_line(*pod_command, "install", allow_errors: true) do |output_type, line|
            line = line.chomp
            case output_type
            when :output
              Support.logger.debug line
            when :error
              Support.logger.warn line
            end
            if line.start_with?("[!] ")
              if IGNORED_COCOAPODS_WARNINGS.any? {|warning| line.include?(warning) }
                warning_not_finished[output_type] = false
              else
                warnings_found[output_type] << line.sub("[!] ", "")
                warning_not_finished[output_type] = line.end_with?(":")
              end
            elsif warning_not_finished[output_type]
              warnings_found[output_type][-1] += "\n" + line
            end
          end
          exited_in_error = (exit_code != 0)
          # CocoaPods 1.0 doesn't update the main repo automatically anymore,
          # so update and retry if an error occured.
          if first_try and exited_in_error
            Support.logger.warn "An error occured during pod install, updating the CocoaPods specs repo before retrying."
            first_try = false
            Support::Shell.run *pod_command, "repo", "update", allow_errors: true
            next
          end
          warnings_found.each do |output_type, messages|
            messages.each do |message|
              @environment.add_issue(
                type: exited_in_error ? :error : :warning,
                tool: :cocoapods,
                description: message.strip,
              )
            end
          end
          break
        end
      end

      def find_unchanged_storyboards
        @environment.action_executed = true
        UnchangedStoryboardFinder.find_issues @environment
      end

      def find_misplaced_constraints
        @environment.action_executed = true
        MisplacedConstraintFinder.find_issues @environment
      end

      private

      def quit_simulator
        Support::Shell.quit_osx_application "iOS Simulator"
      end

      def xcodebuild(project_path, options)
        Support.validate_hash options, requires: [:scheme, :actions, :sdk], can_also_have: [:destination, :archive_path]

        configuration = self.class.read_configuration
        xcode_version = @xcode_version
        if xcode_version == :default and @environment.local_configuration[:xcode_version]
          xcode_version = @environment.local_configuration[:xcode_version].to_s
          xcode_version = :default if xcode_version.downcase == "default"
        end
        if xcode_version == :default
          xcode_version = configuration[:default]
          raise "either set an explicit version of Xcode in the build script, or set a default Xcode version in xcode_versions.yml" unless xcode_version
          # default might point to either a version number or directly to a path
          if configuration[xcode_version]
            xcode_path = configuration[xcode_version]
          else
            xcode_path = xcode_version
          end
        else
          xcode_path = configuration[xcode_version]
        end
        raise "Xcode version #{xcode_version} is not configured in xcode_versions.yml" unless xcode_path
        xcode_path = Support.make_pathname(xcode_path)
        raise "#{xcode_path} doesn't point to a existing Xcode" unless xcode_path.exist?
        xcodebuild_path = xcode_path.join("Contents", "Developer", "usr", "bin", "xcodebuild")
        raise "cannot find xcodebuild at #{xcodebuild_path}" unless xcodebuild_path.exist?

        args = [ xcodebuild_path ]
        case File.extname(project_path)
        when ".xcodeproj"
          args << [ "-project", project_path ]
        when ".xcworkspace"
          args << [ "-workspace", project_path ]
        else
          raise "unknown project type for #{project_path}"
        end
        args << [ "-scheme", options[:scheme] ]
        args << [ "-sdk", options[:sdk] ]
        args << [ "-derivedDataPath", @environment.work_directory ]
        args << [ "-archivePath", options[:archive_path] ] if options[:archive_path]
        args << [ "-destination", options[:destination] ] if options[:destination]
        args << options[:actions]
        args.flatten!

        first_try = true
        loop do
          quit_simulator
          exit_code = nil
          error_extractor = ErrorExtractor.new(@environment)
          Support.logger.info "running #{args.inspect}"
          exit_code = Support::Shell.popen_each_line(*args, allow_errors: true) do |output_type, line|
            error_extractor.process_line(output_type, line)
          end
          error_extractor.flush

          if exit_code != 0 and !error_extractor.new_error_found
            # The simulator and XIB/Storyboard builder are sometimes a bit flaky so retry once if an error occurred.
            if exit_code == 65 and first_try
              Support.logger.warn "An error (#{exit_code}) happened while running running xcodebuild. Retrying once."
              first_try = false
              next
            end
            raise "unknown error (#{exit_code}) happened while running xcodebuild"
          end
          break
        end
      ensure
        quit_simulator
      end

      def self.read_configuration
        configuration_path = BASE_DIRECTORY.join("config", "xcode_versions.yml")
        unless configuration_path.exist?
          # if there is no existing Xcode configuration, just create a default one
          default_path = `xcode-select -p 2> /dev/null`.strip.sub(%r{/Contents/Developer\z}, "")
          default_path = "/Applications/Xcode.app" if default_path.empty?
          IO.write(configuration_path, "default: \"#{default_path}\"")
        end
        raw_configuration = YAML.load(IO.read(configuration_path))
        configuration = {}
        raw_configuration.each do |key, value|
          # 6.2 might be read as a float so make sure to make keys string
          key = key == "default" ? :default : key.to_s
          configuration[key] = value.to_s
        end
        configuration
      end

    end
  end
end
