require 'bundler/setup'
require 'coverage_setup'
require 'minitest/autorun'
require 'active_model_serializers'
require 'fixtures/poro'
require 'fixtures/active_record'

# Ensure backward compatibility with Minitest 4
Minitest::Test = MiniTest::Unit::TestCase unless defined?(Minitest::Test)

module TestHelper
end

