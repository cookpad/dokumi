#!/usr/bin/env ruby
require "minitest/autorun"

$LOAD_PATH.unshift File.expand_path(File.join(File.dirname($0), "..", "lib"))
require "dokumi"

class TestReviewXcodeProject < Minitest::Test
  def build_script
    File.expand_path(File.join(File.dirname($0), "build", "dokumi-test-ios.rb"))
  end

  def test_review_without_error
    issues = Dokumi::Command.review("github.com", "cookpad", "dokumi-test", 1, skip_comment_creation: true, build_script: build_script)
    assert_equal [], issues
  end

  def test_review_with_failing_test
    issues = Dokumi::Command.review("github.com", "cookpad", "dokumi-test", 2, skip_comment_creation: true, build_script: build_script)
    assert_equal 1, issues.length
    issue = issues.first
    assert_equal Dokumi::Support.make_pathname("dokumi-test-iosTests/dokumi_test_iosSuperTests.m"), issue[:file_path]
    assert_equal :error, issue[:type]
    assert_equal 29, issue[:line]
  end

  def test_review_with_unchanged_xib
    issues = Dokumi::Command.review("github.com", "cookpad", "dokumi-test", 3, skip_comment_creation: true, build_script: build_script)
    assert_equal 1, issues.length
    issue = issues.first
    assert_equal Dokumi::Support.make_pathname("dokumi-test-ios/Base.lproj/LaunchScreen.xib"), issue[:file_path]
    assert_equal :error, issue[:type]
  end

  def test_static_analysis
    issues = Dokumi::Command.review("github.com", "cookpad", "dokumi-test", 4, skip_comment_creation: true, build_script: build_script)
    assert_equal 1, issues.length
    issue = issues.first
    assert_equal Dokumi::Support.make_pathname("dokumi-test-ios/ViewController.m"), issue[:file_path]
    assert_equal :static_analyzer, issue[:tool]
    assert_equal :warning, issue[:type]
  end

  def test_review_with_linker_error
    issues = Dokumi::Command.review("github.com", "cookpad", "dokumi-test", 5, skip_comment_creation: true, build_script: build_script)
    assert_equal 1, issues.length
    issue = issues.first
    assert_equal :error, issue[:type]
  end

  def test_import_non_existing_file
    issues = Dokumi::Command.review("github.com", "cookpad", "dokumi-test", 6, skip_comment_creation: true, build_script: build_script)
    assert_equal 1, issues.length
    issue = issues.first
    assert_equal Dokumi::Support.make_pathname("dokumi-test-ios/AppDelegate.m"), issue[:file_path]
    assert_equal :error, issue[:type]
    assert_equal 10, issue[:line]
  end

  def test_important_warning_removed
    issues = Dokumi::Command.review("github.com", "cookpad", "dokumi-test", 10, skip_comment_creation: true, build_script: build_script)
    assert_equal 4, issues.length
    issues.each do |issue|
      assert_nil issue[:file_path]
      assert_nil issue[:line]
      assert_equal :error, issue[:type]
      assert_includes issue[:description], "GCC_WARN_UNDECLARED_SELECTOR"
    end
  end
end
