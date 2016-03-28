module Dokumi
  module Tool
    class Xcode
      MisplacedStatus = Struct.new('MisplacedStatus', :file_path, :line_no)
      # Checks if a pull request contains XIB/Storyboard files which have misplaced constraints.
      class MisplacedConstraintFinder
        def self.find_issues(environment)
          local_copy = environment.options[:local_copy]
          raise "The local copy information is needed to find unchanged files." unless local_copy
          diff = local_copy.diff_with_merge_base
          diff.rugged_diff.each_patch do |patch|
            file_path = patch.delta.new_file[:path]
            next if file_path == nil or patch.delta.binary? or !/\.(storyboard|xib)\z/i.match(file_path)

            misplaced_statuses = []
            patch.each_hunk do |hunk|
              hunk.each_line do |line|
                next unless line.deletion? or line.addition? or line.content.strip.empty?
                line_content = line.content
                tag_type, attributes = Support::XML.read_xml_tag(line_content)
                if attributes.key?(:misplaced) && attributes[:misplaced] == 'YES'
                  misplaced_status = Struct::MisplacedStatus.new(file_path, line.new_lineno)
                  misplaced_statuses << misplaced_status
                end
              end
            end
          end
          misplaced_statuses.each do |status|
            environment.add_issue(
              file_path: status.file_path,
              line: diff.file_line_to_diff_line(file_path)[status.line_no],
              type: :error,
              description: "This constraints is misplaced.",
            )
          end
        end
      end
    end
  end
end
