module Dokumi
  module Tool
    class Xcode
      # Checks if a pull request contains XIB/Storyboard files with the only change being the Xcode version used to save the file.
      class UnchangedStoryboardFinder
        def self.read_xml_tag(text)
          h = {}
          s = StringScanner.new(text)
          return nil unless s.scan(/\s*<([a-zA-Z][a-zA-Z0-9]*)/)
          tag_type = s[1].to_sym
          while s.scan(/\s*([a-zA-Z][a-zA-Z0-9]*)=(?:["'])([^"']+)(["'])\s*/)
            name, value = s[1], s[2]
            h[name.to_sym] = value
          end
          return tag_type, h
        end

        def self.find_issues(environment)
          local_copy = environment.options[:local_copy]
          raise "The local copy information is needed to find unchanged files." unless local_copy
          status_for = {}
          diff = local_copy.diff_with_merge_base
          diff.rugged_diff.each_patch do |patch|
            file_path = patch.delta.new_file[:path]
            next if file_path == nil or patch.delta.binary? or !/\.(storyboard|xib)\z/i.match(file_path)
            unless status_for[file_path]
              status_for[file_path] = {
                found_other_changes: false,
                added: [],
                deleted: [],
              }
            end

            patch.each_hunk do |hunk|
              hunk.each_line do |line|
                next unless line.deletion? or line.addition? or line.content.strip.empty?
                line_content = line.content
                tag_type, attributes = read_xml_tag(line_content)
                if tag_type == :document
                  attributes.delete(:toolsVersion)
                  attributes.delete(:systemVersion)
                elsif tag_type == :plugIn and attributes[:identifier] == "com.apple.InterfaceBuilder.IBCocoaTouchPlugin"
                  attributes.delete(:version)
                else
                  status_for[file_path][:found_other_changes] = true
                  break
                end
                if line.addition?
                  status_for[file_path][:added] << [tag_type, attributes]
                else
                  status_for[file_path][:deleted] << [tag_type, attributes]
                end
              end
              break if status_for[file_path][:found_other_changes]
            end
            break if status_for[file_path][:found_other_changes]
          end
          files_not_changed = []
          status_for.each do |file_path, status|
            found_other_changes = status_for[file_path][:found_other_changes]
            next if found_other_changes
            deleted_left = status[:deleted].dup
            status[:added].each do |tag_type, attribute|
              index = deleted_left.index([tag_type, attribute])
              unless index
                found_other_changes = true
                break
              end
              deleted_left.delete_at index
            end
            next if found_other_changes
            files_not_changed << file_path if deleted_left.empty?
          end
          files_not_changed.each do |file_path|
            environment.add_issue(
              file_path: file_path,
              line: diff.file_line_to_diff_line(file_path).keys.max,
              type: :error,
              description: "A file without a real change should not be added to pull requests.",
            )
          end
        end
      end
    end
  end
end
