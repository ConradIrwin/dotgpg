require "bundler"
Bundler.setup

require "dotgpg"

require "minitest/spec"
require "./spec/helper/assertions"

# Make a totally isolated directory for running tests.
# This is necessary because GPG maintains state in GNUPGHOME,
# and we don't want running the tests to spoil developer's real key stores.
$fixture = Pathname.new(Dir::mktmpdir).realpath
FileUtils.cp_r "spec/fixture/", $fixture
$fixture += "fixture"
$basic = $fixture + "basic"
ENV["GNUPGHOME"] = $fixture.join("gnupghome").to_s
at_exit{ FileUtils.rm_rf $fixture }

require "minitest/autorun"
