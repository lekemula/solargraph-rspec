# frozen_string_literal: true

module SolargraphHelpers
  def load_string(filename, str)
    source = parse_string(filename, str)
    api_map.map(source) # api_map should be defined in the spec
    source
  end

  # Util method to parse (but NOT load) a string
  # This method is mostly here for heredocs
  #
  # @param filename [String]
  # @param str [String] The source code
  #
  # @return [Solargraph::Source]
  def parse_string(filename, str)
    Solargraph::Source.load_string(str, filename)
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

  def completion_pins_at(filename, position, map = api_map)
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
end
