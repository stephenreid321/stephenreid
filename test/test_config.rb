# How tests run: boot, the setup in test/setup, and each test's hooks. Helpers are in test/helpers
$VERBOSE = nil
require File.expand_path('../config/boot', __dir__)

require 'minitest/autorun'
require 'minitest/mock'
require 'active_support/test_case'
require_relative 'helpers/test_helpers'
require_relative 'setup/outside_services'

module ActiveSupport
  class TestCase
    include TestHelpers

    # Each test starts with no stubbed requests, so one it doesn't stub is refused, and with lib/'s memos cleared
    setup do
      OutsideServices.reset!
      IconomiPages.reset!
    end
  end
end
