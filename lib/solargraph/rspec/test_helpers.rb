# frozen_string_literal: true

module Solargraph
  module Rspec
    class TestHelpers
      class GemHelpers < Struct.new(:required_gems, :helper_modules, keyword_init: true)
        # @!attribute [r] required_gems
        #   @return [Array<String>]
        # @!attribute [r] helper_modules
        #   @return [Array<String>]
      end

      class << self
        # @return [String]
        def gem_names
          GEM_HELPERS.flat_map(&:required_gems)
        end

        # @return [Array<String>]
        def helper_module_names
          GEM_HELPERS.flat_map(&:helper_modules)
        end

        # @param root_example_group_namespace_pin [Pin::Namespace]
        # @return [Array<Pin::Reference::Include>]
        def include_helper_pins(root_example_group_namespace_pin:)
          Solargraph.logger.debug "[RSpec] adding helper modules #{helper_module_names}"
          helper_module_names.map do |helper_module|
            PinFactory.build_module_include(
              root_example_group_namespace_pin,
              helper_module,
              root_example_group_namespace_pin.location
            )
          end
        end
      end

      GEM_HELPERS = [
        GemHelpers.new(
          required_gems: %w[rspec],
          helper_modules: %w[RSpec::Matchers]
        ),
        # https://github.com/rspec/rspec-mocks
        GemHelpers.new(
          required_gems: %w[rspec-mocks],
          helper_modules: %w[RSpec::Mocks::ExampleMethods]
        ),
        # @see https://github.com/rspec/rspec-rails#what-tests-should-i-write
        # @see https://github.com/rspec/rspec-rails#helpful-rails-matchers
        GemHelpers.new(
          required_gems: %w[rspec-rails actionmailer activesupport activerecord],
          helper_modules: [
            'RSpec::Rails::Matchers',
            'ActionController::TestCase::Behavior',
            'ActionMailer::TestCase::Behavior',
            'ActiveSupport::Testing::Assertions',
            'ActiveSupport::Testing::TimeHelpers',
            'ActiveSupport::Testing::FileFixtures',
            'ActiveRecord::TestFixtures',
            'ActionDispatch::Integration::Runner',
            'ActionDispatch::Routing::UrlFor',
            'ActionController::TemplateAssertions'
          ]
        ),
        # @see https://matchers.shoulda.io/docs/v6.2.0/#matchers
        GemHelpers.new(
          required_gems: %w[shoulda-matchers],
          helper_modules: [
            'Shoulda::Matchers::ActiveModel',
            'Shoulda::Matchers::ActiveRecord',
            'Shoulda::Matchers::ActionController',
            'Shoulda::Matchers::Routing'
          ]
        ),
        # @see https://github.com/wspurgin/rspec-sidekiq#matchers
        GemHelpers.new(
          required_gems: %w[rspec-sidekiq],
          helper_modules: %w[RSpec::Sidekiq::Matchers]
        ),
        # @see https://github.com/bblimke/webmock#examples
        GemHelpers.new(
          required_gems: %w[webmock],
          helper_modules: %w[WebMock::API WebMock::Matchers]
        ),
        # @see https://github.com/brooklynDev/airborne
        GemHelpers.new(
          required_gems: %w[airborne],
          helper_modules: %w[Airborne]
        )
      ].freeze
    end
  end
end
