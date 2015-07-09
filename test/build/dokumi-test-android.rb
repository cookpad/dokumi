target_project = "app"

case action
when :review
  android.findbugs target_project
else
  raise "unknown action #{action.inspect}"
end
