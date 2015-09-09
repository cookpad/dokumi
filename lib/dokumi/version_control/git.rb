module Dokumi
  module VersionControl
    module Git
      class LocalCopy
        attr_reader :source, :base, :head, :local_repo, :directory

        Reference = Support::FrozenStruct.make_class(:owner, :repo, :ssh_url, :ref, :ref_type, :remote, :local_copy) do
          def last_commit
            local_copy.local_repo.ref("refs/remotes/#{self.remote}/#{self.ref}").target
          end

          def last_commit_id
            last_commit.oid
          end

          def file_in_last_commit?(file_path)
            last_commit.tree.include_file?(local_copy.relative_path(file_path))
          end
        end

        def relative_path(file_path)
          file_path = Support.make_pathname(file_path)
          if file_path.relative?
            file_path
          else
            file_path.relative_path_from(directory)
          end
        end

        def initialize(source, directory)
          @directory = Support.make_pathname(directory)
          @source = source
          source_has_base = source.respond_to?(:base)

          directory.mkpath unless directory.exist?
          raise "#{directory} is not a directory" unless directory.directory?

          unless File.exist?(directory.join(".git"))
            ssh_url = source_has_base ? source.base.ssh_url : source.head.ssh_url
            # cloning or fetching is done using command line git and not Rugged
            # because Rugged doesn't have SSH support by default
            Support::Shell.run "git", "clone", ssh_url, directory
          end

          @local_repo = Rugged::Repository.new(directory.to_s)
          if source_has_base
            @base = Reference.merge(source.base,
              remote: local_repo.create_remote_if_needed(source.base.ssh_url, source.base.owner),
              local_copy: self,
            )
          end
          @head = Reference.merge(source.head,
            remote: local_repo.create_remote_if_needed(source.head.ssh_url, source.head.owner),
            local_copy: self,
          )

          change_directory do
            if source_has_base
              Support::Shell.run "git", "fetch", base.remote
              Support::Shell.run "git", "fetch", head.remote if base.remote != head.remote
            else
              Support::Shell.run "git", "fetch", head.remote
            end
            Support::Shell.run "git", "clean", "-fdx", "-e", "Pods/" # don't remove the Pods/ directory to speed up pod install
            Support::Shell.run "git", "reset", "--hard"
            if head.ref_type == :branch
              Support::Shell.run "git", "checkout", "-f", "#{head.remote}/#{head.ref}"
            else
              Support::Shell.run "git", "checkout", "-f", "#{head.ref}"
            end
            Support::Shell.run "git", "submodule", "sync"
            Support::Shell.run "git", "submodule", "update", "--init"
          end
        end

        def change_directory(&block)
          Support.logger.debug "changing directory to #{directory}"
          Dir.chdir(directory, &block)
          Support.logger.debug "changing directory back to #{Dir.pwd}" if block
        end

        def file_in_head?(file_path)
          local_repo.last_commit.tree.include_file?(relative_path(file_path))
        end

        def diff_with_merge_base
          raise "this should ownly be called when there is a base" unless base

          # Warning: I am not sure this is exactly how GitHub generates the diff for a pull request,
          # but currently no GitHub API endpoint returns the diff GitHub used for location of comments.
          # (The only diff you can get does not take renames into account)
          # The code below should be replaced with using the diff from GitHub once there is a way to get it.
          head_commit = local_repo.last_commit
          base_commit = local_repo.ref("refs/remotes/#{base.remote}/#{base.ref}").target
          merge_base_id = local_repo.merge_base(head_commit, base_commit)
          merge_base = local_repo.lookup(merge_base_id)
          diff = merge_base.diff(head_commit)
          diff.find_similar!(renames: true)

          Git::Diff.new(head_commit.oid, diff, self)
        end

      end

      class Diff
        attr_reader :head_commit_id, :source, :rugged_diff

        def initialize(head_commit_id, rugged_diff, source)
          @head_commit_id = head_commit_id
          @rugged_diff = rugged_diff
          @source = source
        end

        def file_line_to_diff_line(file_name)
          file_name = file_name.to_s # as it might be a Pathname
          return @file_line_to_diff_line[file_name] if @file_line_to_diff_line
          @file_line_to_diff_line = {}
          @rugged_diff.each_patch do |patch|
            file_path = patch.delta.new_file[:path]
            next if patch.delta.binary?
            @file_line_to_diff_line[file_path] ||= {}
            current_diff_line = -1
            patch.each_hunk do |hunk|
              current_diff_line += 1
              line_number = hunk.new_start - 1
              hunk.each_line do |line|
                current_diff_line += 1
                if [:context, :addition].include?(line.line_origin)
                  line_number += 1
                  @file_line_to_diff_line[file_path][line_number] = current_diff_line
                end
              end
            end
          end
          @file_line_to_diff_line[file_name]
        end

        def line_in_diff(relative_path, line_in_file)
          return nil if changed_binary_file?(relative_path)
          return nil unless file_line_to_diff_line(relative_path)
          file_line_to_diff_line(relative_path)[line_in_file]
        end

        def changed_binary_file?(relative_path)
          relative_path = relative_path.to_s # as it might be a Pathname
          return @changed_binary_files.include?(relative_path) if @changed_binary_files
          @changed_binary_files = Set.new
          @rugged_diff.each_delta do |delta|
            @changed_binary_files << delta.new_file[:path] if delta.binary?
          end
          @changed_binary_files.include?(relative_path)
        end

        def file_changed?(relative_path)
          relative_path = relative_path.to_s # as it might be a Pathname
          changed_binary_file?(relative_path) or file_line_to_diff_line(relative_path)
        end

        def line_related_to_changes?(relative_path, line_in_file, opts = {})
          Support.validate_hash opts, only: :lines_around_related
          return true if changed_binary_file?(relative_path)
          lines_around_related = opts[:lines_around_related] || 0

          file_line_to_diff_line_for_file = file_line_to_diff_line(relative_path)
          return false unless file_line_to_diff_line_for_file

          return true if file_line_to_diff_line_for_file[line_in_file]
          return false if lines_around_related == 0

          # keep errors that are close to modified lines even if they are not in the diff
          lines_range = (line_in_file - lines_around_related)..(line_in_file + lines_around_related)
          lines_in_diff = file_line_to_diff_line_for_file.keys
          lines_in_diff.any? {|line| lines_range.include?(line) }
        end

        def filter_out_unrelated_issues(issues, options = {})
          Support.validate_hash options, only: :lines_around_related

          issues.select do |issue|
            if (file_path = issue[:file_path])
              (issue[:type] == :error or
                (file_changed?(file_path) and line_related_to_changes?(file_path, issue[:line], lines_around_related: options[:lines_around_related])))
            else
              true
            end
          end
        end
      end
    end
  end
end
