#!/usr/bin/env ruby
require "minitest/autorun"

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname($0), "..", "lib"))
require "dokumi"

class TestFindbugs < Minitest::Test
  def build_script
    File.expand_path(File.join(File.dirname($0), "build", "dokumi-test-android-findbugs.rb"))
  end

  def test_static_analysis
    issues = Dokumi::Command.review("github.com", "cookpad", "dokumi-test", 7, skip_comment_creation: true, build_script: build_script)
    assert_equal 4, issues.length

    issues.each do |issue|
      assert_equal Dokumi::Support.make_pathname("app/src/main/java/com/cookpad/android/dokumiTestAndroid/MainActivity.java"), issue[:file_path]
      assert_equal :findbugs, issue[:tool]
    end
    assert_equal :error, issues[0][:type]
    assert_equal :warning, issues[1][:type]
    assert_equal :warning, issues[2][:type]
    assert_equal :error, issues[3][:type]
    assert_equal 46, issues[0][:line]
    assert_equal 46, issues[1][:line]
    assert_equal 50, issues[2][:line]
    assert_equal 50, issues[3][:line]
  end
end
