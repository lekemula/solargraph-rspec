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

      FactoryData = Struct.new(
        :factory_names,
        :model_class,
        :traits,
        :kwargs,
        keyword_init: true
      )

      def self.instance
        @instance ||= new
      end

      def self.reset
        @instance = nil
      end

      def pins
        [
          method_builder('create', :instance),
          method_builder('fake_create', :instance),
          method_builder('create', :class),
          method_builder('fake_create', :class),
        ]
      end

      private

      def method_builder(name, scope)
        method = Solargraph::Pin::Method.new(
          name: name,
          scope: scope,
          closure: Solargraph::Pin::Namespace.new(
            name: 'FactoryGirl::Syntax::Methods',
            location: PinFactory.dummy_location('factories.rb')
          )
        )

        method.signatures = factories.map do |d|
          Solargraph::Pin::Signature.new(
            return_type: Solargraph::ComplexType.parse(d.model_class),
            closure: method,
            parameters: [
              Solargraph::Pin::Parameter.new(
                name: 'name',
                return_type: Solargraph::ComplexType.parse(*d.factory_names.map { |n| ":#{n}" }),
                closure: method
              )
            ]
          )
        end

        method
      end

      # @return [Array<FactoryData>]
      def factories
        @factories ||= parse_factories
      end

      def parse_factories
        # @type [Array<Parser::AST::Node>]
        nodes = []

        FACTORY_LOCATIONS.each do |pattern|
          Dir.glob(pattern).each do |file|
            nodes << Solargraph::Parser.parse(File.read(file), file)
          rescue StandardError
            Solargraph.logger.error("[solargraph-rspec] [factory bot] Can't read file #{file}")
          end
        end

        return [] if nodes.empty?

        extract_factories_from_ast(nodes)
      end

      # @param ast [Parser::AST::Node]
      def extract_factories_from_ast(ast)
        walker = Walker.new(ast)
        # @type [Array<FactoryData>]
        factories = []

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

          factories << FactoryData.new(
            factory_names: factory_names,
            model_class: model_class
            # traits: ,
            # kwargs: ,
          )
        end

        walker.walk

        factories
      end
    end
  end
end