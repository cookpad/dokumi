project_name = "dokumi-test-ios.xcodeproj"
to_build = File.exist?("Podfile") ? "dokumi-test-ios.xcworkspace" : project_name
scheme = "dokumi-test-ios"
simulator_destinations = [
  "platform=iOS Simulator,OS=8.4,name=iPhone 4s",
  "platform=iOS Simulator,OS=8.4,name=iPhone 6",
]

xcode.install_pods if File.exist?("Podfile")

case action
when :review
  xcode.require_warnings to_build, scheme: scheme, "GCC_WARN_UNDECLARED_SELECTOR" => "YES"
  xcode.find_unchanged_storyboards
  xcode.analyze(to_build, scheme: scheme) unless error_found?
  xcode.test(to_build, scheme: scheme, destination: simulator_destinations) unless error_found?
else
  raise "unknown action #{action.inspect}"
end
