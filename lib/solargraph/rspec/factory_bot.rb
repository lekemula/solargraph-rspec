# frozen_string_literal: true

require_relative 'factory_bot_walker'

module Solargraph
  module Rspec
    class FactoryBot
      FACTORY_LOCATIONS = [
        'factories.rb',
        'factories/**/*.rb',
        'test/factories.rb',
        'test/factories/**/*.rb',
        'spec/factories.rb',
        'spec/factories/**/*.rb'
      ].freeze

      SYNTAX_MODULES = %w[FactoryBot::Syntax::Methods FactoryGirl::Syntax::Methods].freeze

      # @param factory_names [Array<Symbol>] Names & aliases. The first name is the "official" factory name
      # @param model_class [String] The class that this factory should uses
      # @param traits [Array<Symbol>] A list of trait names
      # @param kwargs [Array<Symbol>] Any available kwargs
      # @param docs [YARD::Docstring] The parsed docs
      FactoryData = Struct.new(:factory_names, :model_class, :traits, :kwargs, :docs, keyword_init: true)

      UnresolvedAssociation = Struct.new(
        # @return [Symbol] The column name
        :column,
        # @return [Symbol] The factory from which this is being made
        :source_factory,
        # @return [Symbol] The factory to which this association associates to
        :target_factory
      )

      def pins
        return [] if factories.empty?

        namespace_pins = SYNTAX_MODULES.flat_map { |name| build_module_chain(name) }
        syntax_pins = namespace_pins.select { |pin| SYNTAX_MODULES.include?(pin.path) }

        namespace_pins + syntax_pins.flat_map do |namespace|
          [
            build_method('create', namespace),
            build_method('build', namespace),
            build_list_method('create', namespace),
            build_list_method('build', namespace)
          ]
        end
      end

      private

      # @param name [String] e.g. `FactoryBot::Syntax::Methods`
      # @return [Array<Solargraph::Pin::Namespace>] The module and each of its enclosing modules
      def build_module_chain(name)
        parts = name.split('::')
        parts.each_index.map do |index|
          Solargraph::Pin::Namespace.new(
            name: parts[0..index].join('::'),
            type: :module,
            location: PinFactory.dummy_location('spec/factories.rb')
          )
        end
      end

      # @param factory [FactoryData]
      # @param method [Solargraph::Pin::Method]
      def signature_for_factory(factory, method)
        sig = Solargraph::Pin::Signature.new(
          return_type: Solargraph::ComplexType.parse(factory.model_class),
          closure: method,
          docstring: factory.docs,
          parameters: []
        )

        sig.parameters << Solargraph::Pin::Parameter.new(
          name: 'name',
          return_type: Solargraph::ComplexType.parse(*factory.factory_names.map { |n| ":#{n}" }),
          closure: sig
        )

        unless factory.traits.empty?
          sig.parameters << Solargraph::Pin::Parameter.new(
            name: 'traits',
            return_type: Solargraph::ComplexType.parse(*factory.traits.map { |n| ":#{n}" }),
            closure: sig,
            decl: :restarg
          )
        end
        sig.parameters += factory.kwargs.map do |n|
          Solargraph::Pin::Parameter.new(
            name: n.to_s,
            closure: sig,
            decl: :kwoptarg
          )
        end

        sig
      end

      def build_list_method(method_prefix, namespace)
        m = build_method("#{method_prefix}_list", namespace)
        m.signatures.each do |sig|
          sig.parameters.insert(
            1,
            Solargraph::Pin::Parameter.new(
              name: 'amount',
              closure: sig,
              return_type: Solargraph::ComplexType.parse('Integer')
            )
          )
        end

        m
      end

      def build_method(method_name, namespace)
        method = Solargraph::Pin::Method.new(
          name: method_name,
          scope: :instance,
          closure: namespace
        )

        method.signatures = factories.map { |f| signature_for_factory(f, method) }

        method
      end

      # @return [Array<FactoryData>]
      def factories
        @factories ||= parse_factories
      end

      def parse_factories
        # @type [Array<FactoryData>]
        factories = []
        # @type [Array<Array(Solargraph::Source, Array<UnresolvedAssociation>)>]
        associations = []

        FACTORY_LOCATIONS.each do |pattern|
          Dir.glob(pattern).each do |file|
            src = Solargraph::Source.load_string(File.read(file), file)
            out = extract_factories_from_source(src)
            factories += out[0]
            associations << [src, out[1]] unless out[1].empty?
          rescue StandardError => e
            Solargraph.logger.error("[solargraph-rspec] [factory bot] Can't read file #{file}: #{e}")
          end
        end

        associations.each do |cfg|
          cfg[1].each do |ass|
            target = factories.find { |f| f.factory_names.include? ass.target_factory }
            source = factories.find { |f| f.factory_names.first == ass.source_factory }
            if target.nil?
              # If we can't find target factory - either its bad indexing or truly undefined
              # We should lean on the more tolerant side & give a warning in logs & just accept whatever comments say
              # If no comments are present, then too bad ig
              Solargraph.logger.warn(
                "[solargraph-rspec] [factory bot] can't map association " \
                "#{ass.source_factory}##{ass.column} (as #{ass.target_factory}) to any factory"
              )
            else
              param = source.docs.tags.find { |t| t.tag_name == 'param' && t.name == ass.column.to_s }
              if param.nil?
                source.docs.add_tag YARD::Tags::Tag.new(:param, '', [target.model_class], ass.column.to_s)
              else
                param.types = [target.model_class]
              end
            end
          end
        end

        factories
      end

      # @param source [Solargraph::Source]
      # @return [Array(Array<FactoryData>, Array<UnresolvedAssociation>)]
      def extract_factories_from_source(source)
        walker = FactoryBotWalker.new(source)
        # @type [Hash{FactoryBotWalker::Factory => FactoryData}]
        factories = {}.compare_by_identity
        # @type [Hash{FactoryData => String}]
        comments = {}.compare_by_identity
        unresolved_associations = []

        walker.on_factory do |factory|
          data = FactoryData.new(
            factory_names: factory.names,
            model_class: factory.class_name || factory.name.to_s.split('_').collect(&:capitalize).join,
            kwargs: [],
            traits: []
          )
          factories[factory] = data
          comments[data] = factory.comments
        end

        walker.on_attribute do |factory, attribute_name, attribute_comments, _location_range|
          data = factories[factory]
          data.kwargs << attribute_name

          comment = comment_for_attribute(attribute_name, attribute_comments)
          comments[data] += "\n#{comment}" unless comment.nil?
        end

        walker.on_association do |factory, attribute_name, target_factory_name, _location_range|
          unresolved_associations << UnresolvedAssociation.new(attribute_name, factory.name, target_factory_name)
        end

        walker.on_trait do |factory, trait_name, _comments, _location_range|
          factories[factory].traits << trait_name
        end

        walker.walk!

        factories.each_value { |data| data.docs = parse_docstring(comments[data]) }

        [factories.values, unresolved_associations]
      end

      # @param comments [String]
      # @return [YARD::Docstring]
      def parse_docstring(comments)
        # Fun fact: solargraph captures errors & guarantees a parser to be returned
        docstring = Solargraph::Source.parse_docstring(comments).to_docstring

        return_tags = docstring.tags(:return)
        unless return_tags.empty?
          # goal is to keep comments but ignore types, so that we can have stuff like create_list
          docstring.delete_tags(:return)
          tag = return_tags.first
          tag.types = nil
          docstring.add_tag(tag)
        end

        docstring
      end

      # @param name [Symbol]
      # @param comment [String]
      # @return [String, nil]
      def comment_for_attribute(name, comment)
        if comment.start_with?('@return ')
          comment = comment[7..]
        elsif comment.start_with?('@type ')
          comment = comment[5..]
        else
          return nil
        end

        "@param #{name}#{comment}"
      end
    end
  end
end
