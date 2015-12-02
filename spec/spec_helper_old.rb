#$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
#require 'nebulous'

RSpec.configure do |config|

  config.expect_with :rspec do |expectations|
    expectations.include_chain_causes_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

end
~