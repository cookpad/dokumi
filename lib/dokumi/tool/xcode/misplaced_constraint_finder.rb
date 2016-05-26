module Dokumi
  module Tool
    class Xcode
      # Checks if a pull request contains XIB/Storyboard files which have misplaced constraints.
      class MisplacedConstraintFinder
        def self.find_issues(environment)
          local_copy = environment.options[:local_copy]
          raise "The local copy information is needed to find unchanged files." unless local_copy
          diff = local_copy.diff_with_merge_base
          diff.rugged_diff.each_patch do |patch|
            file_path = patch.delta.new_file[:path]
            next if file_path == nil or !File.exist?(file_path)
            next if patch.delta.binary?
            next unless /\.(storyboard|xib)\z/i.match(file_path)

            doc = File.open(file_path) { |f| Nokogiri::XML.parse(f) }
            misplaced_nodes = doc.css("[misplaced='YES']")
            misplaced_nodes.each do |node|
              environment.add_issue(
                file_path: file_path,
                line: node.line,
                type: :warning,
                tool: :misplaced_constraint_finder,
                description: "This constraint is misplaced.",
              )
            end
          end
        end
      end
    end
  end
end
