# frozen_string_literal: true

module SolargraphHelpers
  ### Debug Helpers

  def debug_gem_pins(name, load: true, rebuild: true)
    debug_load_gems(name, rebuild: rebuild) if load
    gemspec = Gem::Specification.find_by_name(*name.split('='))
    Solargraph::GemPins.build_yard_pins(gemspec)
  end

  def debug_load_gems(*names, rebuild: true)
    names.each do |name|
      gemspec = Gem::Specification.find_by_name(name)
      api_map.doc_map # HACK: ensure doc_map is initialized
      api_map.cache_gem(gemspec, rebuild: rebuild, out: $stdout)
    end
  end

  ### Spec Helpers

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

  def completion_pins_at(filename, position, map = api_map)
    clip = map.clip_at(filename, position)
    cursor = clip.send(:cursor)
    word = cursor.chain.links.first.word

    # puts "Complete: word=#{word}, links=#{cursor.chain.links}"
    Solargraph.logger.debug(
      "Complete: word=#{word}, links=#{cursor.chain.links}"
    )

    clip.complete.pins
  end

  def completion_at(filename, position, map = api_map)
    completion_pins_at(filename, position, map).map(&:name)
  end
end
