module Dokumi
  module Tool
    class Xcode
      class ProjectHelper
        class Entitlement
          def initialize(plist)
            @plist = plist
          end

          def update_application_groups(&block)
            Support.update_hash!(@plist, "com.apple.security.application-groups/*", &block)
          end
        end

        class InfoPlist
          def initialize(plist)
            @plist = plist
          end

          def update_bundle_identifier(&block)
            Support.update_hash!(@plist, "CFBundleIdentifier", &block)
          end
          def bundle_version=(value)
            Support.update_hash!(@plist, "CFBundleVersion", value)
          end
          def update_watch_app_bundle_identifier_if_present(&block)
            Support.update_hash!(@plist, "WKCompanionAppBundleIdentifier", optional: true, &block)
            Support.update_hash!(@plist, "NSExtension/NSExtensionAttributes/WKAppBundleIdentifier", optional: true, &block)
          end

          def bundle_version
            @plist["CFBundleVersion"]
          end
          def bundle_identifier
            @plist["CFBundleIdentifier"]
          end
        end

        def initialize(xcodeproj_path)
          @xcodeproj_path = Support.make_pathname(xcodeproj_path)
          @xcodeproj = Xcodeproj::Project.open(@xcodeproj_path)
        end

        # Overwrite a build setting in all the targets and schemes.
        def overwrite_in_all_build_settings(key, value)
          each_build_settings do |build_settings|
            build_settings.keys.each do |setting_name|
              build_settings.delete(setting_name) if setting_name.start_with?("#{key}[sdk=")
            end
            build_settings[key] = value
          end
          @xcodeproj.save
        end

        # Remove a build setting in all the targets and schemes.
        def remove_in_all_build_settings(key)
          each_build_settings do |build_settings|
            build_settings.keys.each do |setting_name|
              build_settings.delete(setting_name) if setting_name.start_with?("#{key}[sdk=")
            end
            build_settings.delete(key)
          end
          @xcodeproj.save
        end

        # Set the code signing identity in all the build settings in the project to the value given.
        def code_signing_identity=(value)
          overwrite_in_all_build_settings("CODE_SIGN_IDENTITY", value)
        end

        # Set the provisioning profile in all the build settings in the project to the value given.
        def provisioning_profile=(value)
          overwrite_in_all_build_settings("PROVISIONING_PROFILE", value)
        end

        def overwrite_target_attribute(key, value)
          attributes = @xcodeproj.root_object.attributes
          attributes["TargetAttributes"] ||= {}
          @xcodeproj.targets.each do |target|
            attributes["TargetAttributes"][target.uuid] ||= {}
            if value == nil
              attributes["TargetAttributes"][target.uuid].delete(key)
            else
              attributes["TargetAttributes"][target.uuid][key] = value
            end
          end
          @xcodeproj.save
        end

        # Set the provisioning profile of all the targets in the project to the value given.
        def development_team=(value)
          overwrite_target_attribute("DevelopmentTeam", value)
          overwrite_in_all_build_settings("DEVELOPMENT_TEAM", value) # Xcode 8
        end

        # Set the provisioning profiles for multiple targets. The key is the target's' bundle identifier.
        def update_provisioning_profiles(provisioning_profiles)
          each_build_settings do |build_settings|
            bundle_identifier = build_settings["PRODUCT_BUNDLE_IDENTIFIER"]
            build_settings.keys.each do |setting_name|
              build_settings.delete(setting_name) if setting_name.start_with?("PROVISIONING_PROFILE[sdk=")
            end
            next unless bundle_identifier
            provisioning_profile = provisioning_profiles[bundle_identifier]
            next unless provisioning_profile
            build_settings["PROVISIONING_PROFILE"] = provisioning_profile
          end
          @xcodeproj.save
        end

        # Update all the values of a specific build setting in the project.
        def update_existing_build_setting_values(setting_name_to_update, &block)
          each_build_settings do |build_settings|
            build_settings.keys.each do |setting_name|
              if setting_name_to_update == setting_name or setting_name.start_with?("#{setting_name_to_update}[")
                build_settings[setting_name] = block.call(build_settings[setting_name])
              end
            end
          end
          @xcodeproj.save
        end

        # Update all the values of the PRODUCT_BUNDLE_IDENTIFIER build setting in the project.
        def update_product_bundle_identifier(&block)
          update_existing_build_setting_values("PRODUCT_BUNDLE_IDENTIFIER", &block)
        end

        # To update every entitlement file in the project.
        # An instance of Entitlement will be passed to the block for each entitlement file.
        def update_entitlements(&block)
          update_all_plists_for_build_setting("CODE_SIGN_ENTITLEMENTS") do |plist_content|
            block.call(Entitlement.new(plist_content))
          end
        end

        # To update every Info.plist file in the project.
        # An instance of InfoPlist will be passed to the block for each Info.plist file.
        def update_info_plists(&block)
          update_all_plists_for_build_setting("INFOPLIST_FILE") do |plist_content|
            block.call(InfoPlist.new(plist_content))
          end
        end

        # Returns the paths to every icon in the project.
        # Can be used for example to add a label depending on the branch used to build the project.
        def icon_paths
          icon_paths = []

          # old way to specify icons
          icon_names = []
          all_plists_for_build_setting("INFOPLIST_FILE").each do |path, plist_content|
            keys = plist_content.keys.select {|key| key.start_with?("CFBundleIcons") }
            icon_names << keys.map {|key| plist_content[key]["CFBundlePrimaryIcon"]["CFBundleIconFiles"] }
          end
          icon_names = icon_names.flatten.uniq
          icon_name_regexps = icon_names.map do |icon_name|
            icon_name_extension = File.extname(icon_name)
            if icon_name_extension.empty?
              Regexp.new("\\A#{Regexp.escape(icon_name)}(@[0-9]+x)?\.png\\z")
            else
              Regexp.new("\\A#{Regexp.escape(File.basename(icon_name, icon_name_extension))}(@[0-9]+x)?#{Regexp.escape(icon_name_extension)}\\z")
            end
          end
          icon_paths << find_files_in_project do |project_file_path|
            basenames = [ project_file_path.basename.to_s, project_file_path.basename(project_file_path.extname).to_s ]
            icon_name_regexps.any? {|re| re.match(project_file_path.basename.to_s) }
          end

          # newer way to specify icons
          icon_asset_names = []
          each_build_settings do |build_settings|
            name = build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"]
            icon_asset_names << name if name and !name.empty?
          end
          icon_asset_names.uniq!
          asset_paths = find_files_in_project {|project_file_path| project_file_path.extname == ".xcassets" }
          icon_asset_names.each do |asset_name|
            asset_paths.each do |asset_path|
              json_path = asset_path.join("#{asset_name}.appiconset/Contents.json")
              next unless json_path.exist?
              JSON.parse(IO.read(json_path))["images"].each do |image|
                next unless image["filename"]
                icon_path = json_path.dirname.join(image["filename"])
                icon_paths << icon_path if icon_path.exist?
              end
            end
          end

          icon_paths.flatten.uniq
        end

        private

        def find_files_in_project
          files = @xcodeproj.files.map {|file| file.real_path rescue nil }.compact.uniq
          files.select do |project_file_path|
            to_keep = yield project_file_path
          end
        end

        def each_build_settings
          # to change all build settings, you have to access both
          # configurations attached to the project and configurations attached to each target
          @xcodeproj.build_configurations.each do |build_configuration|
            yield build_configuration.build_settings
          end
          @xcodeproj.targets.each do |target|
            target.build_configurations.each do |build_configuration|
              yield build_configuration.build_settings
            end
          end
        end

        def all_plists_for_build_setting(build_setting_name)
          file_paths = []
          each_build_settings do |build_settings|
            path = build_settings[build_setting_name]
            file_paths << path if path
          end
          file_paths = file_paths.uniq.map {|relative_path| @xcodeproj_path.dirname.join(relative_path).expand_path }.sort
          file_paths.reject {|path| !path.exist? }.map {|path| [ path, Xcodeproj::Plist.read_from_path(path) ] }
        end

        def update_all_plists_for_build_setting(build_setting_name)
          all_plists_for_build_setting(build_setting_name).each do |path, plist_content|
            yield plist_content
            Xcodeproj::Plist.write_to_path(plist_content, path)
          end
        end

      end
    end
  end
end
