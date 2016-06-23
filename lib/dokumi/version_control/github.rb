module Dokumi
  module VersionControl
    module GitHub
      def self.read_configuration
        configuration_path = BASE_DIRECTORY.join("config", "github.yml")
        raw_configuration = YAML.load(IO.read(configuration_path))
        configuration = {}
        raw_configuration.each do |host, configuration_for_host|
          configuration_for_host = Support.symbolize_keys(configuration_for_host)
          Support.validate_hash configuration_for_host, requires_only: [:api_endpoint, :web_endpoint, :access_token]
          configuration[host] = configuration_for_host
        end
        raise "The configuration for at least one GitHub host is needed." if configuration.empty?
        configuration
      end

      def self.make_client(host)
        configuration = read_configuration
        raise "Cannot find the configuration for #{host} in github.yml." unless configuration[host]
        Octokit::Client.new(
          api_endpoint: configuration[host][:api_endpoint],
          web_endpoint: configuration[host][:web_endpoint],
          access_token: configuration[host][:access_token],
          auto_paginate: true,
        )
      end

      # Guess if branch_or_tag_name is a branch name or a tag name
      def self.branch_or_tag(host, owner, repo, branch_or_tag_name)
        if (md = %r{\A(refs/)?tags/(.+)\z}.match(branch_or_tag_name))
          return :tag, md[2]
        end

        github_client = GitHub.make_client(host)
        branches = github_client.branches("#{owner}/#{repo}")
        return :branch, branch_or_tag_name if branches.any? {|branch| branch[:name] == branch_or_tag_name }
        tags = github_client.tags("#{owner}/#{repo}")
        return :tag, branch_or_tag_name if tags.any? {|tag| tag[:name] == branch_or_tag_name }
        raise "cannot find any branch or tag named #{branch_or_tag_name} in #{owner}/#{repo}"
      end

      class Branch
        attr_reader :head

        Reference = Support::FrozenStruct.make_class(:owner, :repo, :ssh_url, :ref, :ref_type)

        def initialize(host, owner, repo, branch_name)
          @github_client = GitHub.make_client(host)
          @github_repository = @github_client.repository({owner: owner, repo: repo})
          @head = Reference.new(
            owner: owner,
            repo: repo,
            ssh_url: @github_repository.ssh_url,
            ref: branch_name,
            ref_type: :branch,
          )
        end

        def fetch_into(directory)
          Git::LocalCopy.new(self, directory)
        end
      end

      class Tag
        attr_reader :head

        Reference = Support::FrozenStruct.make_class(:owner, :repo, :ssh_url, :ref, :ref_type)

        def initialize(host, owner, repo, tag_name)
          @github_client = GitHub.make_client(host)
          @github_repository = @github_client.repository({owner: owner, repo: repo})
          @head = Reference.new(
            owner: owner,
            repo: repo,
            ssh_url: @github_repository.ssh_url,
            ref: tag_name,
            ref_type: :tag,
          )
        end

        def fetch_into(directory)
          Git::LocalCopy.new(self, directory)
        end
      end

      class PullRequest
        attr_reader :base, :head

        Reference = Support::FrozenStruct.make_class(:host, :owner, :repo, :ssh_url, :ref, :ref_type)

        def request_github_pull_request
          @github_client.pull_request({owner: @owner, repo: @repo}, @number)
        end

        def initialize(host, owner, repo, number)
          @host, @owner, @repo, @number = host, owner, repo, number
          @github_client = GitHub.make_client(host)
          @github_pull_request = request_github_pull_request
          @github_commits = @github_pull_request.rels[:commits].get.data

          github_base = @github_pull_request.base
          @base = Reference.new(
            owner: owner,
            repo: repo,
            ssh_url: github_base.repo.ssh_url,
            ref: github_base.ref,
            ref_type: :branch,
          )

          github_head = @github_pull_request.head
          @head = Reference.new(
            owner: github_head.user.login,
            repo: github_head.repo.name,
            ssh_url: github_head.repo.ssh_url,
            ref: github_head.ref,
            ref_type: :branch,
          )
        end

        def fetch_into(directory)
          Git::LocalCopy.new(self, directory)
        end

        def validate_comment(comment)
          Support.validate_hash comment, requires: :body, can_also_have: [:line_in_diff, :file_path, :commit_id]
          if [:file_path, :line_in_diff, :commit_id].any? {|key| comment[key] }
            unless [:file_path, :line_in_diff, :commit_id].all? {|key| comment[key] }
              raise "You must give either none or all of file path, line in diff and commit."
            end
          end
        end

        def add_comment(comment)
          validate_comment comment
          repo = {owner: base.owner, repo: base.repo}
          if comment[:commit_id]
            @github_client.create_pull_request_comment(repo, @number, comment[:body], comment[:commit_id], comment[:file_path], comment[:line_in_diff])
          else
            @github_client.add_comment(repo, @number, comment[:body])
          end
        rescue Octokit::UnprocessableEntity => e
          Support.logger.error "Error posting comment #{comment.inspect}: #{e.inspect}"
        end

        def has_comment?(comment)
          validate_comment comment
          if comment[:commit_id]
            @review_comments ||= @github_pull_request.rels[:review_comments].get.data
            @review_comments.any? do |github_comment|
              github_comment.body == comment[:body] and
                github_comment.commit_id == comment[:commit_id] and
                github_comment.path == comment[:file_path] and
                github_comment.position == comment[:line_in_diff]
            end
          else
            @comments ||= @github_pull_request.rels[:comments].get.data
            @comments.any? {|github_comment| github_comment.body == comment[:body] }
          end
        end

        def body
          @github_pull_request['body']
        end

        def web_url_for_file_in_commit(relative_path, commit_id)
          "#{@github_pull_request.head.repo.html_url}/blob/#{commit_id}/#{relative_path}"
        end

        def self.markdown_for_issue(issue)
          Support.validate_hash issue, requires: [:type, :description]
          tool_name = issue[:tool].to_s.capitalize.gsub(/_[a-z]/) {|string| " " + string[-1].upcase }
          case issue[:type]
          when :warning
            "**#{tool_name} Warning:** #{issue[:description]}"
          when :error
            "**#{tool_name} Error:** #{issue[:description]}"
          else
            raise "Unknown issue type #{issue[:type]}"
          end
        end

        def add_comments_for_issues(issues, diff)
          issues = issues.sort_by {|issue| [issue[:file_path] || Pathname.new(""), issue[:line] || 0] }
          comment_markdown = ""
          previous_file_path = nil
          issues.each do |issue|
            line_in_file = issue[:line]
            line_in_diff = diff.line_in_diff(issue[:file_path], line_in_file) if line_in_file
            if line_in_file and line_in_diff
              body = self.class.markdown_for_issue(issue)
              comment = {
                body: body,
                file_path: issue[:file_path].to_s,
                line_in_diff: line_in_diff,
                commit_id: diff.head_commit_id,
              }
              add_comment(comment) unless has_comment?(comment)
            else
              if issue[:file_path]
                file_in_tree = diff.source.file_in_head?(issue[:file_path])
                file_url = web_url_for_file_in_commit(issue[:file_path], diff.head_commit_id) if file_in_tree
                if previous_file_path != issue[:file_path]
                  if file_in_tree
                    comment_markdown << "\n[#{issue[:file_path]}](#{file_url}):\n"
                  else
                    comment_markdown << "\n#{issue[:file_path]}:\n"
                  end
                end
              else
                comment_markdown << "\n"
              end
              line = issue[:line]
              comment_markdown << "- "
              if line
                if file_in_tree
                  comment_markdown << "[line #{line}](#{file_url}#L#{line}): "
                else
                  comment_markdown << "line #{line}: "
                end
              end
              comment_markdown << "#{self.class.markdown_for_issue(issue)}\n"
              previous_file_path = issue[:file_path]
            end
          end

          comment_markdown.strip!
          comment = {body: comment_markdown}
          add_comment(comment) if comment_markdown.length > 0 and !has_comment?(comment)
        end
      end
    end
  end
end
