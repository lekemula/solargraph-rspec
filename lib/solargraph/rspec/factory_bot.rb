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

      ALWAYS_IGNORE = %i[after before callbacks to_create].freeze
      SPECIAL_CALLBACKS = %i[add_attribute sequence association trait].freeze

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
        :target_factory,
        # @return [::Parser::AST::Node] The node that does the association
        :node
      )

      def self.instance
        @instance ||= new
      end

      def self.reset
        @instance = nil
      end

      def pins
        return [] if factories.empty?

        namespaces = [
          Solargraph::Pin::Namespace.new(
            name: 'FactoryGirl::Syntax::Methods',
            location: PinFactory.dummy_location('spec/factories.rb')
          ),
          Solargraph::Pin::Namespace.new(
            name: 'FactoryBot::Syntax::Methods',
            location: PinFactory.dummy_location('spec/factories.rb')
          )
        ]

        # Tmp change: this is done for debug.
        # In the end the scope should always be :instance
        [:class, :instance].flat_map do |scope|
          namespaces.flat_map do |ns|
            [
              build_method('create', ns, scope),
              build_method('build', ns, scope),
              build_list_method('create', ns, scope),
              build_list_method('build', ns, scope)
            ]
          end
        end
      end

      private

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
            decl: :kwoptarg,
          )
        end

        sig
      end

      def build_list_method(method_prefix, ns, scope)
        m = build_method("#{method_prefix}_list", ns, scope)
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

      def build_method(method_name, ns, scope)
        method = Solargraph::Pin::Method.new(
          name: method_name,
          scope: scope,
          closure: ns
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
              Solargraph.logger.warn("[solargraph-rspec] [factory bot] can't map association #{ass.source_factory}##{ass.column} (as #{ass.target_factory}) to any factory")
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

      # @param src [Solargraph::Source]
      # @return [Array(Array<FactoryData>, Array<UnresolvedAssociation>)]
      def extract_factories_from_source(src)
        walker = Walker.new(src.node)
        # @type [Array<FactoryData>]
        factories = []
        unresolved_associations = []

        walker.on :block, [:send, nil, :factory] do |ast|
          factory_cfg = ast.children.first.children
          next if factory_cfg.length < 3
          next unless factory_cfg[2].type == :sym

          # @type [Array<Symbol>]
          factory_names = [factory_cfg[2].children[0]]
          model_class = factory_names[0].to_s.split('_').collect(&:capitalize).join

          if factory_cfg.length > 3 && factory_cfg[3].type == :hash
            factory_cfg[3].children.each do |pair|
              case pair.children[0].children[0]
              when :aliases
                if pair.children[1].type == :array
                  pair.children[1].children.each do |n|
                    factory_names << n.children[0] if n.type == :sym
                  end
                end
              when :class
                if pair.children[1].type == :str
                  model_class = pair.children[1].children[0]
                elsif pair.children[1].type == :const
                  model_class = pair.children[1].children[1].to_s
                end
              end
            end
          end

          kwargs = []
          traits = []
          comments = src.comments_for(ast) || ''

          unless ast.children[2].nil?
            w = Walker.new(ast.children[2])

            w.on :send do |ast|
              col = ast.children[1]
              next if ALWAYS_IGNORE.include? col

              if SPECIAL_CALLBACKS.include? col
                # these lads need an arg or more
                next if ast.children.length < 3
                next unless ast.children[2].type == :sym

                mod = col
                col = ast.children[2].children.first

                if mod == :trait
                  # Traits can't have docs so
                  traits << col
                  next
                elsif mod == :association
                  unresolved_associations << UnresolvedAssociation.new(col, factory_names.first, extract_association_name_from_ast(col, ast), ast)
                end
              end

              comment = comment_for_attribute(src, col, ast)
              comments += "#{comment}\n" unless comment.nil?
              kwargs << col
            end

            w.walk
          end

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

          factories << FactoryData.new(
            factory_names: factory_names,
            model_class: model_class,
            kwargs: kwargs,
            traits: traits,
            docs: docstring
          )
        end

        walker.walk

        [factories, unresolved_associations]
      end

      def comment_for_attribute(src, name, node)
        comment = src.comments_for(node)
        return nil if comment.nil?

        if comment.start_with?('@return ')
          comment = comment[7..]
        elsif comment.start_with?('@type ')
          comment = comment[5..]
        else
          return nil
        end

        "@param #{name}#{comment}"
      end

      # @param col [Symbol]
      # @param ast [::Parser::AST::Node]
      def extract_association_name_from_ast(col, ast)
        return col if ast.children.last&.type != :hash

        factory_pair = ast.children.last.children.find do |n|
          n.type == :pair && n.children[0].type == :sym && n.children[0].children[0] == :factory
        end
        return col if factory_pair.nil?

        if factory_pair.children[1].type == :array
          return col if factory_pair.children[1].children.empty?

          name = factory_pair.children[1].children.first
        else
          name = factory_pair.children[1]
        end

        return col if name.type != :sym

        name.children[0]
      end
    end
  end
end
