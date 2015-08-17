module Dokumi
  module Tool
    class Xcode
      # Note that the -pedantic warnings are not handled yet.
      class ProjectChecker
        # The groups can be found in clang's include/clang/Basic/DiagnosticGroups.td.
        WARNING_GROUPS = {
          "conversion" => [
            "bool-conversion",
            "constant-conversion",
            "enum-conversion",
            "float-conversion",
            "shorten-64-to-32",
            "int-conversion",
            "literal-conversion",
            "non-literal-null-conversion",
            "null-conversion",
            "objc-literal-conversion",
            "sign-conversion",
            "string-conversion",
          ],
          "unused" => [
            "unused-argument",
            "unused-function",
            "unused-label",
            "unused-private-field",
            "unused-local-typedef",
            "unused-value",
            "used-variable",
            "unused-property-ivar",
          ],
          "deprecated" => [
            "deprecated-declarations",
            "deprecated-increment-bool",
            "deprecated-register",
            "deprecated-writable-strings",
          ],
        }.freeze

        # Remarks about Xcode settings:
        # - The flags have been a been cleaned up in some cases:
        #   * -Werror-xxxxx -> -Werror=xxxxx
        #   * -Wxxxxx -Werror=xxxxx -> -Werror=xxxxx
        # - The default values are the values when the setting is not in the project file,
        #   not the values in a new project created by Xcode.
        XCODE_SETTINGS = {
          "CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES" => {
            description: "Allow Non-modular Includes In Framework Modules",
            default: :NO,
            flags: {
              YES: "",
              NO: "-Werror=non-modular-include-in-framework-module",
            },
          },
          "CLANG_WARN_ASSIGN_ENUM" => {
            description: "Out-of-Range Enum Assignments",
            default: :NO,
            flags: {
              YES: "-Wassign-enum",
              NO: "",
            },
          },
          "CLANG_WARN_BOOL_CONVERSION" => {
            description: "Implicit Boolean Conversions",
            default_from: "CLANG_WARN_SUSPICIOUS_IMPLICIT_CONVERSION",
            flags: {
              YES: "-Wbool-conversion",
              NO: "-Wno-bool-conversion",
            },
          },
          "CLANG_WARN_CONSTANT_CONVERSION" => {
            description: "Implicit Constant Conversions",
            default_from: "CLANG_WARN_SUSPICIOUS_IMPLICIT_CONVERSION",
            flags: {
              YES: "-Wconstant-conversion",
              NO: "-Wno-constant-conversion",
            },
          },
          "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS" => {
            description: "Overriding Deprecated ObjC Methods",
            default: :NO,
            flags: {
              YES: "-Wdeprecated-implementations",
              NO: "-Wno-deprecated-implementations",
            },
          },
          "CLANG_WARN_DIRECT_OBJC_ISA_USAGE" => {
            description: "Direct usage of isa",
            default: :YES,
            flags: {
              YES: "-Wdeprecated-objc-isa-usage", # Xcode does not give it to clang as it is on by default but we need it for resolution.
              YES_ERROR: "-Werror=deprecated-objc-isa-usage",
              NO: "-Wno-deprecated-objc-isa-usage",
            },
          },
          "CLANG_WARN_DOCUMENTATION_COMMENTS" => {
            description: "Documentation Comments",
            default: :NO,
            flags: {
              YES: "-Wdocumentation",
              NO: "",
            },
          },
          "CLANG_WARN_EMPTY_BODY" => {
            description: "Empty Loop Bodies",
            default: :NO,
            flags: {
              YES: "-Wempty-body",
              NO: "-Wno-empty-body",
            },
          },
          "CLANG_WARN_ENUM_CONVERSION" => {
            description: "Implicit Enum Conversions",
            default_from: "CLANG_WARN_SUSPICIOUS_IMPLICIT_CONVERSION",
            flags: {
              YES: "-Wenum-conversion",
              NO: "-Wno-enum-conversion",
            },
          },
          "CLANG_WARN_IMPLICIT_SIGN_CONVERSION" => {
            description: "Implicit Signedness Conversions",
            default: :NO,
            flags: {
              YES: "-Wsign-conversion",
              NO: "-Wno-sign-conversion",
            },
          },
          "CLANG_WARN_INT_CONVERSION" => {
            description: "Implicit Integer to Pointer Conversions",
            default_from: "CLANG_WARN_SUSPICIOUS_IMPLICIT_CONVERSION",
            flags: {
              YES: "-Wint-conversion",
              NO: "-Wno-int-conversion",
            },
          },
          "CLANG_WARN_OBJC_EXPLICIT_OWNERSHIP_TYPE" => {
            description: "Implicit ownership types on out parameters",
            default: :NO,
            flags: {
              YES: "-Wexplicit-ownership-type",
              NO: "",
            },
          },
          "CLANG_WARN_OBJC_IMPLICIT_ATOMIC_PROPERTIES" => {
            description: "Implicit Atomic Objective-C Properties",
            default: :NO,
            flags: {
              YES: "-Wimplicit-atomic-properties",
              NO: "-Wno-implicit-atomic-properties",
            },
          },
          "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF" => {
            description: "Implicit retain of 'self' within blocks",
            default: :NO,
            flags: {
              YES: "-Wimplicit-retain-self",
              NO: "",
            },
          },
          "CLANG_WARN_OBJC_MISSING_PROPERTY_SYNTHESIS" => {
            description: "Implicit Synthesized Properties",
            default: :NO,
            flags: {
              YES: "-Wobjc-missing-property-synthesis",
              NO: "",
            },
          },
          "CLANG_WARN_OBJC_RECEIVER_WEAK" => {
            description: "Sending messages to __weak pointers",
            default: :NO,
            flags: {
              YES: "-Wreceiver-is-weak",
              NO: "-Wno-receiver-is-weak",
            },
          },
          "CLANG_WARN_OBJC_REPEATED_USE_OF_WEAK" => {
            description: "Repeatedly using a __weak reference",
            default: :NO,
            flags: {
              YES: "-Warc-repeated-use-of-weak",
              NO: "-Wno-arc-repeated-use-of-weak",
            },
          },
          "CLANG_WARN_OBJC_ROOT_CLASS" => {
            description: "Unintentional Root Class",
            default: :YES,
            flags: {
              YES: "-Wobjc-root-class", # Xcode does not give it to clang as it is on by default but we need it for resolution.
              YES_ERROR: "-Werror=objc-root-class",
              NO: "-Wno-objc-root-class",
            },
          },
          "CLANG_WARN_SUSPICIOUS_IMPLICIT_CONVERSION" => {
            description: "Suspicious Implicit Conversions",
            default: :NO,
            flags: {
              YES: "-Wconversion",
              NO: "-Wno-conversion",
            },
          },
          "CLANG_WARN_UNREACHABLE_CODE" => {
            description: "Unreachable Code",
            default: :NO,
            flags: {
              YES: "-Wunreachable-code",
              NO: "",
            },
          },
          "CLANG_WARN__ARC_BRIDGE_CAST_NONARC" => {
            description: "Using __bridge Casts Outside of ARC",
            default: :YES,
            flags: {
              YES: "-Warc-bridge-casts-disallowed-in-nonarc", # Xcode does not give it to clang as it is on by default but we need it for resolution.
              NO: "-Wno-arc-bridge-casts-disallowed-in-nonarc",
            },
          },
          "CLANG_WARN__DUPLICATE_METHOD_MATCH" => {
            description: "Duplicate Method Definitions",
            default: :NO,
            flags: {
              YES: "-Wduplicate-method-match",
              NO: "",
            },
          },
          "GCC_TREAT_IMPLICIT_FUNCTION_DECLARATIONS_AS_ERRORS" => {
            description: "Treat Missing Function Prototypes as Errors",
            default: :NO,
            flags: {
              YES: "-Werror=implicit-function-declaration",
              NO: "",
            },
          },
          "GCC_TREAT_INCOMPATIBLE_POINTER_TYPE_WARNINGS_AS_ERRORS" => {
            description: "Treat Incompatible Pointer Type Warnings as Errors",
            default: :NO,
            flags: {
              YES: "-Werror=incompatible-pointer-types",
              NO: "",
            },
          },
          "GCC_TREAT_WARNINGS_AS_ERRORS" => {
            description: "Treat Warnings as Errors",
            default: :NO,
            flags: {
              YES: "-Werror",
              NO: "",
            },
          },
          "GCC_WARN_64_TO_32_BIT_CONVERSION" => {
            description: "Implicit Conversion to 32 Bit Type",
            default: :YES,
            flags: {
              YES: "-Wshorten-64-to-32",
              NO: "-Wno-shorten-64-to-32",
            },
          },
          "GCC_WARN_ABOUT_DEPRECATED_FUNCTIONS" => {
            description: "Deprecated Functions",
            default: :YES,
            flags: {
              YES: "-Wdeprecated-declarations",
              NO: "-Wno-deprecated-declarations",
            },
          },
          "GCC_WARN_ABOUT_INVALID_OFFSETOF_MACRO" => {
            description: "Undefined Use of offsetof Macro",
            default: :YES,
            flags: {
              YES: "-Winvalid-offsetof",
              NO: "-Wno-invalid-offsetof ",
            },
          },
          "GCC_WARN_ABOUT_MISSING_FIELD_INITIALIZERS" => {
            description: "Missing Fields in Structure Initializers",
            default: :NO,
            flags: {
              YES: "-Wmissing-field-initializers",
              NO: "-Wno-missing-field-initializers",
            },
          },
          "GCC_WARN_ABOUT_MISSING_NEWLINE" => {
            description: "Missing Newline At End Of File",
            default: :NO,
            flags: {
              YES: "-Wnewline-eof",
              NO: "-Wno-newline-eof",
            },
          },
          "GCC_WARN_ABOUT_MISSING_PROTOTYPES" => {
            description: "Missing Function Prototypes",
            default: :NO,
            flags: {
              YES: "-Wmissing-prototypes",
              NO: "-Wno-missing-prototypes",
            },
          },
          "GCC_WARN_ABOUT_POINTER_SIGNEDNESS" => {
            description: "Pointer Sign Comparison",
            default: :YES,
            flags: {
              YES: "-Wpointer-sign",
              NO: "-Wno-pointer-sign",
            },
          },
          "GCC_WARN_ABOUT_RETURN_TYPE" => {
            description: "Mismatched Return Type",
            default: :NO,
            flags: {
              YES: "-Wreturn-type", # Xcode does not give it to clang as it is on by default but we need it for resolution.
              YES_ERROR: "-Werror=return-type",
              NO: "-Wno-return-type",
            },
          },
          "GCC_WARN_ALLOW_INCOMPLETE_PROTOCOL" => {
            description: "Incomplete Objective-C Protocols",
            default: :YES,
            flags: {
              YES: "-Wprotocol",
              NO: "-Wno-protocol",
            },
          },
          "GCC_WARN_CHECK_SWITCH_STATEMENTS" => {
            description: "Check Switch Statements",
            default: :YES,
            flags: {
              YES: "-Wswitch",
              NO: "-Wno-switch",
            },
          },
          "GCC_WARN_FOUR_CHARACTER_CONSTANTS" => {
            description: "Four Character Literals",
            default: :NO,
            flags: {
              YES: "-Wfour-char-constants",
              NO: "-Wno-four-char-constants",
            },
          },
          "GCC_WARN_INHIBIT_ALL_WARNINGS" => {
            description: "Inhibit All Warnings",
            default: :NO,
            flags: {
              YES: "-w",
              NO: "",
            },
          },
          "GCC_WARN_INITIALIZER_NOT_FULLY_BRACKETED" => {
            description: "Initializer Not Fully Bracketed",
            default: :NO,
            flags: {
              YES: "-Wmissing-braces",
              NO: "-Wno-missing-braces",
            },
          },
          "GCC_WARN_MISSING_PARENTHESES" => {
            description: "Missing Braces and Parentheses",
            default: :YES,
            flags: {
              YES: "-Wparentheses",
              NO: "-Wno-parentheses",
            },
          },
          "GCC_WARN_MULTIPLE_DEFINITION_TYPES_FOR_SELECTOR" => {
            description: "Multiple Definition Types for Selector",
            default: :NO,
            flags: {
              YES: "-Wselector",
              NO: "-Wno-selector",
            },
          },
          "GCC_WARN_SHADOW" => {
            description: "Hidden Local Variables",
            default: :NO,
            flags: {
              YES: "-Wshadow",
              NO: "-Wno-shadow",
            },
          },
          "GCC_WARN_SIGN_COMPARE" => {
            description: "Sign Comparison",
            default: :NO,
            flags: {
              YES: "-Wsign-compare",
              NO: "",
            },
          },
          "GCC_WARN_STRICT_SELECTOR_MATCH" => {
            description: "Strict Selector Matching",
            default: :NO,
            flags: {
              YES: "-Wstrict-selector-match",
              NO: "-Wno-strict-selector-match",
            },
          },
          "GCC_WARN_TYPECHECK_CALLS_TO_PRINTF" => {
            description: "Typecheck Calls to printf/scanf",
            default: :YES,
            flags: {
              YES: "-Wformat", # Xcode does not give it to clang as it is on by default but we need it for resolution.
              NO: "-Wno-format",
            },
          },
          "GCC_WARN_UNDECLARED_SELECTOR" => {
            description: "Undeclared Selector",
            default: :NO,
            flags: {
              YES: "-Wundeclared-selector",
              NO: "-Wno-undeclared-selector",
            },
          },
          "GCC_WARN_UNINITIALIZED_AUTOS" => {
            description: "Uninitialized Variables",
            default: :NO,
            flags: {
              YES: "-Wuninitialized",
              YES_AGGRESSIVE: "-Wconditional-uninitialized",
              NO: "-Wno-uninitialized",
            },
          },
          "GCC_WARN_UNKNOWN_PRAGMAS" => {
            description: "Unknown Pragma",
            default: :NO,
            flags: {
              YES: "-Wunknown-pragmas",
              NO: "-Wno-unknown-pragmas",
            },
          },
          "GCC_WARN_UNUSED_FUNCTION" => {
            description: "Unused Functions",
            default: :NO,
            flags: {
              YES: "-Wunused-function",
              NO: "-Wno-unused-function",
            },
          },
          "GCC_WARN_UNUSED_LABEL" => {
            description: "Unused Labels",
            default: :NO,
            flags: {
              YES: "-Wunused-label",
              NO: "-Wno-unused-label",
            },
          },
          "GCC_WARN_UNUSED_PARAMETER" => {
            description: "Unused Parameters",
            default: :NO,
            flags: {
              YES: "-Wunused-parameter",
              NO: "-Wno-unused-parameter",
            },
          },
          "GCC_WARN_UNUSED_VALUE" => {
            description: "Unused Values",
            default: :YES,
            flags: {
              YES: "-Wunused-value",
              NO: "-Wno-unused-value",
            },
          },
          "GCC_WARN_UNUSED_VARIABLE" => {
            description: "Unused Variables",
            default: :NO,
            flags: {
              YES: "-Wunused-variable",
              NO: "-Wno-unused-variable",
            },
          },
          "OTHER_CFLAGS" => {
            description: "Other C Flags",
            default: "",
          },
          "WARNING_CFLAGS" => {
            description: "Other Warning Flags",
            default: "",
          },
        }.freeze

        def find_setting_with_flag(flag_wanted)
          XCODE_SETTINGS.each do |setting_name, setting|
            next unless setting[:flags]
            setting[:flags].each do |value, flag|
              return {setting: setting, setting_name: setting_name, value: value} if flag == flag_wanted
            end
          end
          nil
        end

        def add_error(options)
          Support.validate_hash options, requires_only: [:warning, :configuration, :target, :wanted]
          state_wanted = options[:wanted]
          warning = options[:warning]
          configuration_name = options[:configuration]
          target_name = options[:target]

          flag_wanted = case state_wanted
          when true then "-W#{warning}"
          when false then "-Wno-#{warning}"
          when :error then "-Werror=#{warning}"
          else raise "Unknown value #{state_wanted.inspect}"
          end

          configuration_description = %{On build configuration "#{configuration_name}" of target "#{target_name}", please}
          place = find_setting_with_flag(flag_wanted)
          if place
            @environment.add_issue type: :error, description: %{#{configuration_description} change the setting #{place[:setting_name]} ("#{place[:setting][:description]}") to #{place[:value]}.}
            return
          end
          if state_wanted == :error
            place = find_setting_with_flag("-W#{warning}")
            if place
              @environment.add_issue type: :error, description: %{#{configuration_description} change the setting #{place[:setting_name]} ("#{place[:setting][:description]}") and GCC_TREAT_WARNINGS_AS_ERRORS ("Treat Warnings as Errors") to YES, or add "#{flag_wanted}" to WARNING_CFLAGS ("Other Warning Flags").}
              return
            end
          end
          @environment.add_issue type: :error, description: %{#{configuration_description} add "#{flag_wanted}" to WARNING_CFLAGS ("Other Warning Flags").}
        end

        def require_warnings(*warnings)
          schemes = nil
          warnings = warnings.flatten
          warnings_hash = Support.extract_options!(warnings).dup
          schemes = warnings_hash.delete(:scheme)
          warnings_wanted = resolve_warnings(wanted_warnings_to_flags(*warnings, warnings_hash))

          build_configurations_used = Set.new
          if schemes
            schemes = [ schemes ].flatten
            schemes.each do |scheme|
              build_configurations_used += build_configurations_used_by_scheme(scheme)
            end
          else
            @project.build_configurations.each {|configuration| build_configurations_used << configuration.name }
          end

          @project.targets.each do |target|
            target.build_configurations.each do |configuration|
              next unless build_configurations_used.include?(configuration.name)
              resolved_flags = resolve_flags(target.name, configuration.name)
              resolved_warnings = resolve_warnings(resolved_flags)
              if resolved_warnings == {}
                @environment.add_issue type: :error, description: "The target #{target.name} should not have all its warnings inhibited on configuration #{configuration.name}."
                next
              end

              warnings_wanted.each do |warning, state_wanted|
                resolved_value = resolved_warnings[warning]
                error_found = false
                if state_wanted == false
                  error_found = true if resolved_value
                elsif state_wanted == :error
                  error_found = true if resolved_value != :error
                elsif state_wanted == true
                  error_found = true unless resolved_value # true or :error are both fine
                else
                  raise "Unknown value #{state_wanted.inspect} wanted for warning #{warning}."
                end
                add_error(warning: warning, configuration: configuration.name, target: target, wanted: state_wanted) if error_found
              end
            end
          end
        end

        private

        def build_configurations_used_by_scheme(scheme_name)
          shared_data_dir = Support.make_pathname(Xcodeproj::XCScheme.shared_data_dir(@project.path))
          scheme_file_path = shared_data_dir.join("#{scheme_name}.xcscheme")
          raise "Cannot find file for scheme #{scheme_name} (expecting #{scheme_file_path})" unless scheme_file_path.exist?

          # The current version of Xcodeproj does not let you load scheme so we have to do it by hand.
          document = File.open(scheme_file_path) {|f| Nokogiri::XML.parse(f) }
          build_configuration_used = Set.new
          ["BuildAction", "TestAction", "LaunchAction", "ProfileAction", "AnalyzeAction"].each do |action_type|
            document.xpath("/Scheme/#{action_type}").each do |node|
              build_configuration = node["buildConfiguration"]
              build_configuration_used << build_configuration if build_configuration
            end
          end
          if build_configuration_used.empty?
            raise "Cannot find any build configuration used for the scheme #{scheme_name} of #{project_path}"
          end
          build_configuration_used
        end

        def normalize_setting_value(value)
          return :YES if value == true
          return :NO if value == false
          case value.to_s.downcase.to_sym
          when :yes
            return :YES
          when :no
            return :NO
          when :error, :yes_error
            return :YES_ERROR
          when :aggressive, :yes_aggressive
            return :YES_AGGRESSIVE
          end
          raise "Invalid value #{value.inspect}"
        end

        def wanted_warnings_to_flags(*warnings)
          wanted_flags = []
          options = Support.extract_options!(warnings)
          warnings.each do |name|
            name = name.to_s
            if setting = XCODE_SETTINGS[name]
              wanted_flags << XCODE_SETTINGS[name][:flags][:YES]
            elsif name.start_with?("-W")
              wanted_flags << name
            elsif /\A[a-z#][a-z\-=#]+\z/.match(name)
              wanted_flags << "-W#{name}"
            else
              setting = XCODE_SETTINGS.values.find {|setting| setting[:description] == name }
              if setting
                wanted_flags << setting[:flags][:YES]
              else
                raise "Unknown warning #{name}"
              end
            end
          end
          options.each do |name, value|
            name = name.to_s
            normalized_value = normalize_setting_value(value)
            if setting = XCODE_SETTINGS[name]
              flags = setting[:flags][normalized_value]
              raise "Invalid value #{value.inspect} for #{name}" unless flags
              wanted_flags << flags
            elsif /\A[a-z#][a-z\-=#]+\z/.match(name)
              if normalized_value == :YES
                wanted_flags << "-W#{name}"
              elsif normalized_value == :YES_ERROR
                wanted_flags << "-Werror=#{name}"
              elsif normalized_value == :NO
                wanted_flags << "-Wno-#{name}"
              else
                raise "Could not figure what warning you meant by {#{name.inspect} => #{value.inspect}}."
              end
            else
              setting = XCODE_SETTINGS.values.find {|setting| setting[:description] == name }
              if setting
                flags = setting[:flags][normalized_value]
                raise "Invalid value #{value.inspect} for #{name}" unless flags
                wanted_flags << flags
              else
                raise "Unknown warning #{name}"
              end
            end
          end
          clean_up_flags(wanted_flags)
        end

        def initialize(environment, path)
          @environment = environment
          @project = Xcodeproj::Project.open(path)
        end

        def read_build_setting(setting_name, project_level_build_settings, target_build_settings)
          value = target_build_settings[setting_name] || project_level_build_settings[setting_name]
          return value if value

          setting = XCODE_SETTINGS[setting_name]
          if setting[:default_from]
            return read_build_setting(setting[:default_from], project_level_build_settings, target_build_settings)
          elsif setting[:default]
            return setting[:default]
          else
            raise "Default value for build setting #{setting_name} unknown."
          end
        end

        def clean_up_flags(flags)
          flags.flatten.map {|flag| flag.split(/\s+/) }.flatten.map {|flag| flag.strip }.reject(&:empty?)
        end

        def flag_and_each_child(flag)
          yield flag
          if children = WARNING_GROUPS[flag]
            children.each {|child_flag| yield child_flag }
          end
        end

        def resolve_flags(target_name, build_configuration_name)
          flags = []
          project_level_build_configuration = @project.build_configurations.find {|configuration| configuration.name == build_configuration_name }
          raise "Could not find configuration #{build_configuration_name} at project level." unless project_level_build_configuration
          project_level_build_settings = project_level_build_configuration.build_settings
          target = @project.targets.find {|target| target.name == target_name }
          target_build_configuration = target.build_configurations.find {|configuration| configuration.name == build_configuration_name }
          raise "Could not find configuration #{build_configuration_name} in target #{target.name}." unless target_build_configuration
          target_build_settings = target_build_configuration.build_settings

          XCODE_SETTINGS.each do |setting_name, setting|
            next unless setting[:flags]
            value = read_build_setting(setting_name, project_level_build_settings, target_build_settings).to_sym
            flags_for_setting = setting[:flags][value]
            raise "Unknown value #{value.inspect} for #{name}." unless flags_for_setting
            flags << flags_for_setting
          end
          flags << read_build_setting("WARNING_CFLAGS", project_level_build_settings, target_build_settings)
          flags << read_build_setting("OTHER_CFLAGS", project_level_build_settings, target_build_settings)
          clean_up_flags(flags)
        end

        def resolve_warnings(flags)
          warning_states = {}
          warnings_as_errors = false
          flags.each do |flag|
            case flag
            when "-w"
              {}
            when "-Werror"
              warnings_as_errors = true
            # Both -Werror-XXXX and -Werror=XXXX are valid.
            when /\A-Werror[=\-](.+)\z/
              flag_and_each_child($1) {|key| warning_states[key] = :error }
            when /\A-Wno-error[=\-](.+)\z/
              flag_and_each_child($1) {|key| warning_states[key] = true if warning_states[key] }
            when /\A-Wno-(.+)\z/
              flag_and_each_child($1) {|key| warning_states[key] = false }
            when /\A-W(.+)\z/
              # Error or not depends on -Werror is on or not
              flag_and_each_child($1) {|key| warning_states[key] = :default }
            end
          end
          default_value = warnings_as_errors ? :error : true
          warning_states.keys.each do |flag|
            warning_states[flag] = default_value if warning_states[flag] == :default
          end
          warning_states
        end
      end
    end
  end
end
