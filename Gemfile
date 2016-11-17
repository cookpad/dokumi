source "https://rubygems.org"

gem "octokit"
gem "rugged"
gem "xcodeproj", "~> 1.3.3"
gem "nokogiri"
gem "activesupport", [">= 4.2", "< 5.0"] # 5.0 requires Ruby 2.2.2 so force an older version

custom_gemfile_path = File.join(File.dirname(__FILE__), 'custom', 'Gemfile')
eval_gemfile custom_gemfile_path if File.exist?(custom_gemfile_path)
