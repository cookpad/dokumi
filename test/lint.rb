#!/usr/bin/env ruby
require "minitest/autorun"

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname($0), "..", "lib"))
require "dokumi"

class TestFindbugs < Minitest::Test
  def build_script
    File.expand_path(File.join(File.dirname($0), "build", "dokumi-test-android-lint.rb"))
  end

  def test_static_analysis
    issues = Dokumi::Command.review("github.com", "cookpad", "dokumi-test", 13, skip_comment_creation: true, build_script: build_script)
    
    assert_equal 3, issues.length
    issues.each { |issue| assert_equal :lint, issue[:tool] }

    # issues[0]
    assert_equal :error, issues[0][:type]
    assert_equal 15, issues[0][:line]
    # issues[1]
    assert_equal :warning, issues[1][:type]
    assert_equal 10, issues[1][:line]
    # issues[2]
    assert_equal :warning, issues[2][:type]
    assert_equal 7, issues[2][:line]

  end
end
