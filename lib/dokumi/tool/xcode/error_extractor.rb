module Dokumi
  module Tool
    class Xcode
      class ErrorExtractor
        attr_reader :new_error_found

        def initialize(environment)
          @environment = environment
          @linker_error_state = :out
          @undefined_symbol_details = nil
          @new_error_found = false
        end

        def process_line(output_type, line)
          line = line.rstrip
          case output_type
          when :error
            process_standard_error_line(line)
          when :output
            process_standard_output_line(line)
          else
            raise "invalid output type #{output_type.inspect}"
          end
        end

        def flush
          add_issue_if_needed
          @linker_error_state = :out
        end

        private

        def clean_up_issue_type(type)
          type = type.gsub(" ", "_").to_sym
          type = :error if type == :fatal_error
          type
        end

        def add_issue_if_needed
          if @undefined_symbol_details and !@undefined_symbol_details[:files].empty?
            description = "Cannot find symbol #{@undefined_symbol_details[:symbol]} referenced in #{@undefined_symbol_details[:files].join(", ")}"
            @environment.add_issue(
              type: :error,
              tool: :linker,
              description: description,
            )
            @new_error_found = true
          end
          @undefined_symbol_details = nil
        end

        def process_standard_error_line(line)
          Support.logger.error line.chomp
        end

        def extract_simple_error(line)
          if (md = /\A(.+):(\d+):(\d+): (fatal error|error|warning): (.+)\z/.match(line))
            file_path, line_number, column, issue_type, description = md.captures
          elsif (md = /\A(.+):(\d+): (fatal error|error|warning): (.+)\z/.match(line))
            file_path, line_number, issue_type, description = md.captures
            column = nil
          else
            return false
          end
          issue_type = clean_up_issue_type(issue_type)
          @new_error_found = true if issue_type == :error
          issue = {}
          if description.end_with?(" - FAIL")
            issue[:tool] = :automatic_tests
            description = description.sub(/ - FAIL\z/, "")
          end
          issue[:type] = issue_type
          issue[:description] = description
          if file_path != "<unknown>"
            issue[:file_path] = file_path
            issue[:line] = line_number.to_i
            issue[:column] = column.to_i if column
          end
          @environment.add_issue issue
          return true
        end

        def extract_linker_error(line)
          case @linker_error_state
          when :out
            if md = /\AUndefined symbols for architecture (.*):\z/.match(line)
              @linker_error_state = :inside_undefined_symbols
              @undefined_symbol_details = nil
            end
          when :inside_undefined_symbols
            if (md = /\A  "(.+)", referenced from:\z/.match(line))
              symbol = md[1].sub("_OBJC_CLASS_$_", "")
              add_issue_if_needed
              @undefined_symbol_details = { symbol: symbol, files: [] }
            elsif (md = /\A      [a-zA-Z0-9\-]+ in (.+\.o)\z/.match(line))
              file_name = md[1]
              raise "could not find what the undefined symbol for #{file_name} was" unless @undefined_symbol_details
              @undefined_symbol_details[:files] << file_name
            elsif /\(maybe you meant:/.match(line)
              # ignored
            else
              flush
              # try parsing this line once again in the :out state
              extract_linker_error(line)
            end
          else
            raise "invalid state"
          end
        end

        def process_standard_output_line(line)
          if extract_simple_error(line)
            Support.logger.warn line.chomp
            flush
            return
          end
          Support.logger.debug line.chomp
          extract_linker_error(line)
        end

      end
    end
  end
end
