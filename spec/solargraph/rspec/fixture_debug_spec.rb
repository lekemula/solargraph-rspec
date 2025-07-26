# frozen_string_literal: true

# NOTE: This spec is disabled and meant only for debugging rspec files specifically.
# It loads external fixture files to test solargraph-rspec completion behavior.
# Enable by changing `xdescribe` to `describe` when debugging fixture file completion.

RSpec.xdescribe 'Fixture Debug' do
  let(:api_map) { Solargraph::ApiMap.new }
  let(:library) { Solargraph::Library.new }

  it 'completes fixture file go-to-definition' do
    # Edit the fixture file to test completion behavior
    fixture_filename = File.expand_path('spec/fixtures/sample_spec.rb')
    fixture_content = File.read(fixture_filename)

    load_string fixture_filename, fixture_content

    # Change this to your desired completion point
    expect(completion_at(fixture_filename, [7, 5])).to include('user')
  end
end
