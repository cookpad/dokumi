require "fileutils"
require "set"
require "yaml"
require "pathname"
require "shellwords"
require "xcodeproj"
require "strscan"
require "rugged"
require "octokit"
require "open3"
require "pp"
require "json"
require "tmpdir"
require "nokogiri"
require "logger"

module Dokumi
  BASE_DIRECTORY = Pathname.new(__FILE__).dirname.parent.realpath
end

require "dokumi/support"
require "dokumi/version_control"
require "dokumi/command"
require "dokumi/build_environment"
