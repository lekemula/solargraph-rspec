# frozen_string_literal: true

module SolargraphHelpers
  def load_string(filename, str)
    source = Solargraph::Source.load_string(str, filename)
    api_map.map(source) # api_map should be defined in the spec
    source
  end

  def load_sources(*sources)
    source_maps = sources.map { |s| Solargraph::SourceMap.map(s) }
    bench = Solargraph::Bench.new(source_maps: source_maps)
    api_map.catalog bench # api_map should be defined in the spec
  end

  def assert_public_instance_method(map, query, return_type)
    pin = find_pin(query, map)
    expect(pin).to_not be_nil, "Method #{query} not found"
    expect(pin.scope).to eq(:instance)
    expect(pin.return_type.map(&:tag)).to eq(return_type)

    yield pin if block_given?
  end

  def assert_public_instance_method_inferred_type(map, query, return_type)
    pin = find_pin(query, map)
    expect(pin).to_not be_nil, "Method #{query} not found"
    expect(pin.scope).to eq(:instance)
    inferred_return_type = pin.probe(api_map).simplify_literals.to_s

    expect(inferred_return_type).to eq(return_type)

    yield pin if block_given?
  end

  def assert_class_method(map, query, return_type)
    pin = find_pin(query, map)
    expect(pin).to_not be_nil
    expect(pin.scope).to eq(:class)
    expect(pin.return_type.map(&:tag)).to eq(return_type)

    yield pin if block_given?
  end

  def assert_namespace(map, query)
    pin = find_pin(query, map)
    expect(pin).to_not be_nil
    expect(pin.scope).to eq(:class)
    expect(pin.return_type.map(&:tag)).to eq(["Class<#{query}>"])

    yield pin if block_given?
  end

  def find_pin(path, map = api_map)
    find_pins(path, map).first
  end

  def find_pins(path, map = api_map)
    map.pins.select { |p| p.path == path }
  end

  # @return [Array<Solargraph::Pin::Base>]
  def completion_pins_at(filename, position, map = api_map)
    # @type [Solargraph::SourceMap::Clip]
    clip = map.clip_at(filename, position)
    cursor = clip.send(:cursor)
    word = cursor.chain.links.first.word

    Solargraph.logger.debug(
      "Complete: word=#{word}, links=#{cursor.chain.links}"
    )

    clip.complete.pins
  end

  def completion_at(filename, position, map = api_map)
    completion_pins_at(filename, position, map).map(&:name)
  end

  # Expect that a local can be inferred with +expected_type+
  #
  # @param var_name [String]
  # @param expected_type [String]
  # @param file [String] The filename (defaults to filename defined in test)
  # @param map [Solargraph::ApiMap] The Api Map (defaults to the one defined in a test)
  #
  # @return [Solargraph::Pin::BaseVariable] The variable pin
  def expect_local_variable_type(var_name, expected_type, file = filename, map = api_map)
    var_pin = map.source_map(file).locals.find { |p| p.name == var_name }
    expect(var_pin).not_to be_nil
    expect(var_pin.probe(map).to_s).to eql(expected_type)

    var_pin
  end
end
