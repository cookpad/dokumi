target_project = "app"

case action
when :review
  android.infer target_project
else
  raise "unknown action #{action.inspect}"
end
