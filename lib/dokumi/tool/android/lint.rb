module Dokumi
  module Tool
    class Android
      class Lint
          LINT_REPORT_FILE = "build/outputs/lint-results.xml"
        
        class << self
          def parse_report(target_project)
            report_path = Support.make_pathname(target_project).join(LINT_REPORT_FILE)
            File.open(report_path) do |file|
              report = Nokogiri::XML(file)

              report.xpath("//issue").map do |issue|
                { description: issue.attribute("message").to_s,
                  file_path: issue.xpath("location/@file").to_s,
                  line: issue.xpath("location/@line").to_s.to_i,
                  type: issue.attribute("severity").to_s == "Error" ? :error : :warning,
                }
              end
            end
          end
        end
      end
    end
  end
end
