#!/usr/bin/env ruby
require "minitest/autorun"

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname($0), "..", "lib"))
require "dokumi"

class TestInfer < Minitest::Test
  def build_script
    File.expand_path(File.join(File.dirname($0), "build", "dokumi-test-android-infer.rb"))
  end

  def test_static_analysis
    issues = Dokumi::Command.review("github.com", "cookpad", "dokumi-test", 9, skip_comment_creation: true, build_script: build_script)
    assert_equal 2, issues.length

    issues.each do |issue|
      assert_equal Dokumi::Support.make_pathname("app/src/main/java/com/cookpad/android/dokumiTestAndroid/MainActivity.java"), issue[:file_path]
      assert_equal :static_analysis, issue[:type]
    end
    assert_equal 52, issues[0][:line]
    assert_equal 71, issues[1][:line]
  end
end
