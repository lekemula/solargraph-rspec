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
      # @param model_class [String] The class that this factory builds
      # @param class_name [String, nil] The class given via the `class:` option
      # @param parent [Symbol, nil] The factory this one inherits from
      # @param modification [Boolean] Whether the factory is re-opened by `FactoryBot.modify`
      # @param traits [Hash{Symbol => String}] Trait names and their comments
      # @param kwargs [Array<Symbol>] Any available kwargs
      # @param docs [YARD::Docstring] The parsed docs
      # @param location [Solargraph::Location] Where the factory is defined
      FactoryData = Struct.new(
        :factory_names, :model_class, :class_name, :parent, :modification, :traits, :kwargs, :docs, :location,
        keyword_init: true
      )

      UnresolvedAssociation = Struct.new(
        # @return [Symbol] The column name
        :column,
        # @return [Symbol] The factory from which this is being made
        :source_factory,
        # @return [Symbol] The factory to which this association associates to
        :target_factory
      )

      # @return [Array<Solargraph::Pin::Base>]
      def pins
        namespace_pins + SYNTAX_MODULES.flat_map { |namespace| method_pins(namespace) }
      end

      # @return [Array<Solargraph::Pin::Namespace>] The syntax modules and their enclosing modules
      def namespace_pins
        return [] if factories.empty?

        @namespace_pins ||= SYNTAX_MODULES.flat_map { |name| build_module_chain(name) }
      end

      # @param namespace [String] e.g. `FactoryBot::Syntax::Methods`
      # @return [Array<Solargraph::Pin::Method>]
      def method_pins(namespace)
        syntax_pin = namespace_pins.find { |pin| pin.path == namespace }
        return [] unless syntax_pin

        @method_pins ||= {}
        @method_pins[namespace] ||= [
          build_method('create', syntax_pin),
          build_method('build', syntax_pin),
          build_method('create_list', syntax_pin, list: true),
          build_method('build_list', syntax_pin, list: true)
        ]
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
      # @param list [Boolean] Whether the method builds a list of models, e.g. `create_list`
      # @return [Solargraph::Pin::Signature]
      def signature_for_factory(factory, method, list: false)
        sig = Solargraph::Pin::Signature.new(
          return_type: Solargraph::ComplexType.parse(list ? "Array<#{factory.model_class}>" : factory.model_class),
          closure: method,
          docstring: signature_docstring(factory),
          location: factory.location,
          parameters: []
        )

        sig.parameters << Solargraph::Pin::Parameter.new(
          name: 'name',
          return_type: Solargraph::ComplexType.parse(*factory.factory_names.map { |n| ":#{n}" }),
          closure: sig
        )

        if list
          sig.parameters << Solargraph::Pin::Parameter.new(
            name: 'amount',
            return_type: Solargraph::ComplexType.parse('Integer'),
            closure: sig
          )
        end

        unless factory.traits.empty?
          sig.parameters << Solargraph::Pin::Parameter.new(
            name: 'traits',
            return_type: Solargraph::ComplexType.parse(*factory.traits.keys.map { |n| ":#{n}" }),
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

      # @param factory [FactoryData]
      # @return [YARD::Docstring]
      def signature_docstring(factory)
        docstring = factory.docs.dup
        return docstring if factory.traits.empty?

        traits_doc = factory.traits.map do |name, comment|
          comment.empty? ? "`:#{name}`" : "`:#{name}` (#{comment})"
        end.join(', ')
        docstring.add_tag(YARD::Tags::Tag.new(:param, traits_doc, nil, 'traits'))
        docstring
      end

      # @param method_name [String]
      # @param namespace [Solargraph::Pin::Namespace]
      # @param list [Boolean]
      # @return [Solargraph::Pin::Method]
      def build_method(method_name, namespace, list: false)
        method = Solargraph::Pin::Method.new(
          name: method_name,
          scope: :instance,
          closure: namespace
        )

        method.signatures = factories.map { |f| signature_for_factory(f, method, list: list) }

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

        factories = merge_modified_factories(factories)
        factories.each { |factory| factory.model_class = resolve_model_class(factory, factories) }

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

        inherit_from_parents(factories)

        factories
      end

      # `FactoryBot.modify` re-opens a factory, so definitions sharing a name are merged into the first one
      #
      # @param factories [Array<FactoryData>]
      # @return [Array<FactoryData>]
      def merge_modified_factories(factories)
        factories.group_by { |factory| factory.factory_names.first }.values.map do |definitions|
          definitions.sort_by { |definition| definition.modification ? 1 : 0 }.reduce do |merged, definition|
            merged.factory_names |= definition.factory_names
            merged.class_name ||= definition.class_name
            merged.parent ||= definition.parent
            merged.kwargs |= definition.kwargs
            merged.traits = definition.traits.merge(merged.traits)
            add_missing_param_tags(merged.docs, definition.docs)
            merged
          end
        end
      end

      # @param factory [FactoryData]
      # @param factories [Array<FactoryData>]
      # @return [String]
      def resolve_model_class(factory, factories)
        return factory.class_name if factory.class_name

        parent = ancestors(factory, factories).find(&:class_name)
        return parent.class_name if parent

        root = ancestors(factory, factories).last || factory
        root.factory_names.first.to_s.split('_').collect(&:capitalize).join
      end

      # @param factories [Array<FactoryData>]
      # @return [void]
      def inherit_from_parents(factories)
        own = factories.to_h { |factory| [factory, [factory.kwargs, factory.traits, factory.docs]] }

        factories.each do |factory|
          ancestors(factory, factories).each do |ancestor|
            kwargs, traits, docs = own[ancestor]
            factory.kwargs = kwargs | factory.kwargs
            factory.traits = traits.merge(factory.traits)
            add_missing_param_tags(factory.docs, docs)
          end
        end
      end

      # @param factory [FactoryData]
      # @param factories [Array<FactoryData>]
      # @return [Array<FactoryData>] The parent, grand-parent and so on
      def ancestors(factory, factories)
        result = []
        current = factory

        while current.parent
          current = factories.find { |f| f.factory_names.include?(current.parent) }
          break if current.nil? || result.include?(current) || current.equal?(factory)

          result << current
        end

        result
      end

      # @param docs [YARD::Docstring]
      # @param other_docs [YARD::Docstring]
      # @return [void]
      def add_missing_param_tags(docs, other_docs)
        other_docs.tags(:param).each do |tag|
          docs.add_tag(tag) unless docs.tags(:param).any? { |t| t.name == tag.name }
        end
      end

      # @param source [Solargraph::Source]
      # @return [Array(Array<FactoryData>, Array<UnresolvedAssociation>)]
      def extract_factories_from_source(source)
        walker = FactoryBotWalker.new(source)
        # @type [Hash{FactoryBotWalker::Factory => FactoryData}]
        factories = {}.compare_by_identity
        # @type [Hash{FactoryData => String}]
        comments = {}.compare_by_identity
        # @type [Hash{FactoryData => Array<YARD::Tags::Tag>}]
        attribute_tags = Hash.new { |h, k| h[k] = [] }.compare_by_identity
        unresolved_associations = []

        walker.on_factory do |factory|
          data = FactoryData.new(
            factory_names: factory.names,
            class_name: factory.class_name,
            parent: factory.parent,
            modification: factory.modification,
            location: Solargraph::Location.new(File.expand_path(source.filename), factory.location_range),
            kwargs: [],
            traits: {}
          )
          factories[factory] = data
          comments[data] = factory.comments
        end

        walker.on_attribute do |factory, attribute_name, attribute_comments, _location_range|
          data = factories[factory]
          data.kwargs << attribute_name unless data.kwargs.include?(attribute_name)

          tag = param_tag_for_attribute(attribute_name, attribute_comments)
          attribute_tags[data] << tag if tag
        end

        walker.on_association do |factory, attribute_name, target_factory_name, _location_range|
          unresolved_associations << UnresolvedAssociation.new(attribute_name, factory.name, target_factory_name)
        end

        walker.on_trait do |factory, trait_name, trait_comments, _location_range|
          factories[factory].traits[trait_name] = trait_comments.tr("\n", ' ')
        end

        walker.walk!

        factories.each_value do |data|
          data.docs = parse_docstring(comments[data])
          attribute_tags[data].each do |tag|
            data.docs.add_tag(tag) unless data.docs.tags(:param).any? { |t| t.name == tag.name }
          end
        end

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
      # @param comment [String] e.g. `Given name` or `@return [String] Given name`
      # @return [YARD::Tags::Tag, nil]
      def param_tag_for_attribute(name, comment)
        # `@type` takes a variable name in Solargraph, so read it as `@return` to keep the text
        docstring = Solargraph::Source.parse_docstring(comment.gsub(/^@type /, '@return ')).to_docstring
        tag = docstring.tag(:return)
        text = [docstring.to_s, tag&.text].compact.reject(&:empty?).join("\n")
        return if text.empty? && tag&.types.nil?

        YARD::Tags::Tag.new(:param, text, tag&.types, name.to_s)
      end
    end
  end
end
