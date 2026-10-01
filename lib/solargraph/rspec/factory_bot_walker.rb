# frozen_string_literal: true

require_relative 'walker'
require_relative 'spec_walker/full_constant_name'

module Solargraph
  module Rspec
    # Walks FactoryBot (or FactoryGirl) definition files and yields the factories, attributes, associations and
    # traits declared in them.
    #
    # @example
    #   walker = FactoryBotWalker.new(source)
    #   walker.on_factory { |factory| ... }
    #   walker.on_attribute { |factory, attribute_name, comments, location_range| ... }
    #   walker.walk!
    class FactoryBotWalker
      DEFINE_RECEIVERS = %i[FactoryBot FactoryGirl].freeze
      DEFINE_METHODS = %i[define modify].freeze
      TRANSIENT_METHODS = %i[transient ignore].freeze
      NAMED_ATTRIBUTE_METHODS = %i[add_attribute sequence].freeze
      IGNORED_METHODS = %i[
        after before callback callbacks to_create skip_create initialize_with traits_for_enum
      ].freeze

      # A factory definition, as written in the source
      #
      # @!attribute [r] names
      #   @return [Array<Symbol>] The factory name followed by its aliases
      # @!attribute [r] class_name
      #   @return [String, nil] The `class:` option, when given
      # @!attribute [r] parent
      #   @return [Symbol, nil] The enclosing factory's name, or the `parent:` option
      # @!attribute [r] comments
      #   @return [String] The comments preceding the factory definition
      # @!attribute [r] modification
      #   @return [Boolean] Whether the factory is re-opened by `FactoryBot.modify`
      # @!attribute [r] location_range
      #   @return [Solargraph::Range]
      Factory = Struct.new(
        :names, :class_name, :parent, :comments, :modification, :location_range,
        keyword_init: true
      ) do
        # @return [Symbol]
        def name
          names.first
        end
      end

      # @param source [Solargraph::Source]
      def initialize(source)
        @source = source
        @walker = Rspec::Walker.new(source.node)
        @handlers = {
          on_factory: [],
          on_attribute: [],
          on_association: [],
          on_trait: [],
          after_walk: []
        }
      end

      # @param block [Proc]
      # @yieldparam factory [Factory]
      # @return [void]
      def on_factory(&block)
        @handlers[:on_factory] << block
      end

      # Yields every attribute a factory accepts as an override, including transient attributes, sequences and
      # associations.
      #
      # @param block [Proc]
      # @yieldparam factory [Factory]
      # @yieldparam attribute_name [Symbol]
      # @yieldparam comments [String]
      # @yieldparam location_range [Solargraph::Range]
      # @return [void]
      def on_attribute(&block)
        @handlers[:on_attribute] << block
      end

      # @param block [Proc]
      # @yieldparam factory [Factory]
      # @yieldparam attribute_name [Symbol]
      # @yieldparam target_factory_name [Symbol]
      # @yieldparam location_range [Solargraph::Range]
      # @return [void]
      def on_association(&block)
        @handlers[:on_association] << block
      end

      # @param block [Proc]
      # @yieldparam factory [Factory]
      # @yieldparam trait_name [Symbol]
      # @yieldparam comments [String]
      # @yieldparam location_range [Solargraph::Range]
      # @return [void]
      def on_trait(&block)
        @handlers[:on_trait] << block
      end

      # @param block [Proc]
      # @return [void]
      def after_walk(&block)
        @handlers[:after_walk] << block
      end

      # @return [void]
      def walk!
        @walker.on :block do |block_ast|
          next unless define_block?(block_ast)

          modification = block_ast.children[0].children[1] == :modify
          each_statement(block_ast.children[2]) do |statement|
            visit_factory(statement, modification: modification) if call_name(statement) == :factory
          end
        end

        @walker.walk

        @handlers[:after_walk].each(&:call)
      end

      private

      # @param node [::Parser::AST::Node]
      # @return [Boolean]
      def define_block?(node)
        send_node = node.children[0]
        receiver = send_node.children[0]

        send_node.type == :send &&
          DEFINE_METHODS.include?(send_node.children[1]) &&
          receiver.is_a?(::Parser::AST::Node) &&
          receiver.type == :const &&
          DEFINE_RECEIVERS.include?(receiver.children[1])
      end

      # @param node [::Parser::AST::Node] `factory` call, with or without a block
      # @param parent [Factory, nil]
      # @param modification [Boolean]
      # @return [void]
      def visit_factory(node, parent = nil, modification: parent&.modification || false)
        name = symbol_value(call_args(node).first)
        return unless name

        options = hash_options(call_args(node)[1])
        factory = Factory.new(
          names: [name] + Array(options[:aliases]&.children).filter_map { |n| symbol_value(n) },
          class_name: class_name_value(options[:class]),
          parent: symbol_value(options[:parent]) || parent&.name,
          comments: comments_for(node),
          modification: modification,
          location_range: Solargraph::Parser.node_range(node)
        )

        @handlers[:on_factory].each { |handler| handler.call(factory) }

        each_statement(block_body(node)) { |statement| visit_factory_statement(statement, factory) }
      end

      # @param node [::Parser::AST::Node]
      # @param factory [Factory]
      # @return [void]
      def visit_factory_statement(node, factory)
        method_name = call_name(node)
        return if method_name.nil? || IGNORED_METHODS.include?(method_name)

        args = call_args(node)

        case method_name
        when :factory
          visit_factory(node, factory)
        when :trait
          trait_name = symbol_value(args.first)
          return unless trait_name

          call_handlers(:on_trait, factory, trait_name, comments_for(node), Solargraph::Parser.node_range(node))
          each_statement(block_body(node)) { |statement| visit_factory_statement(statement, factory) }
        when *TRANSIENT_METHODS
          each_statement(block_body(node)) { |statement| visit_factory_statement(statement, factory) }
        when :association
          attribute_name = symbol_value(args.first)
          visit_attribute(node, factory, attribute_name, association_target(attribute_name, args[1])) if attribute_name
        when *NAMED_ATTRIBUTE_METHODS
          attribute_name = symbol_value(args.first)
          visit_attribute(node, factory, attribute_name) if attribute_name
        else
          # `author factory: :user` is an implicit association
          target = association_target(method_name, args.first) if hash_options(args.first).key?(:factory)
          visit_attribute(node, factory, method_name, target)
        end
      end

      # @param node [::Parser::AST::Node]
      # @param factory [Factory]
      # @param attribute_name [Symbol]
      # @param target_factory_name [Symbol, nil]
      # @return [void]
      def visit_attribute(node, factory, attribute_name, target_factory_name = nil)
        location_range = Solargraph::Parser.node_range(node)

        call_handlers(:on_attribute, factory, attribute_name, comments_for(node), location_range)
        return unless target_factory_name

        call_handlers(:on_association, factory, attribute_name, target_factory_name, location_range)
      end

      # @param attribute_name [Symbol]
      # @param options_node [::Parser::AST::Node, nil]
      # @return [Symbol]
      def association_target(attribute_name, options_node)
        factory_option = hash_options(options_node)[:factory]
        # `factory: [:user, :admin]` names the factory followed by its traits
        factory_option = factory_option.children.first if factory_option&.type == :array

        symbol_value(factory_option) || attribute_name
      end

      # @param handler_name [Symbol]
      # @param args [Array]
      # @return [void]
      def call_handlers(handler_name, *args)
        @handlers[handler_name].each { |handler| handler.call(*args) }
      end

      # @param node [::Parser::AST::Node, nil]
      # @yieldparam statement [::Parser::AST::Node]
      # @return [void]
      def each_statement(node, &block)
        return unless node.is_a?(::Parser::AST::Node)

        node.type == :begin ? node.children.each(&block) : yield(node)
      end

      # @param node [::Parser::AST::Node]
      # @return [::Parser::AST::Node, nil] The receiver-less method call of a statement
      def call_node(node)
        return unless node.is_a?(::Parser::AST::Node)

        node = node.children[0] if node.type == :block
        node if node.type == :send && node.children[0].nil?
      end

      # @param node [::Parser::AST::Node]
      # @return [Symbol, nil]
      def call_name(node)
        call_node(node)&.children&.[](1)
      end

      # @param node [::Parser::AST::Node]
      # @return [Array<::Parser::AST::Node>]
      def call_args(node)
        call_node(node)&.children&.drop(2) || []
      end

      # @param node [::Parser::AST::Node]
      # @return [::Parser::AST::Node, nil]
      def block_body(node)
        node.children[2] if node.type == :block
      end

      # @param node [::Parser::AST::Node, nil]
      # @return [Hash{Symbol => ::Parser::AST::Node}]
      def hash_options(node)
        return {} unless node.is_a?(::Parser::AST::Node) && node.type == :hash

        node.children.each_with_object({}) do |pair, options|
          next unless pair.type == :pair

          key = symbol_value(pair.children[0])
          options[key] = pair.children[1] if key
        end
      end

      # @param node [::Parser::AST::Node, nil]
      # @return [Symbol, nil]
      def symbol_value(node)
        return unless node.is_a?(::Parser::AST::Node) && %i[sym str].include?(node.type)

        node.children[0].to_sym
      end

      # @param node [::Parser::AST::Node, nil]
      # @return [String, nil]
      def class_name_value(node)
        return unless node.is_a?(::Parser::AST::Node)
        return SpecWalker::FullConstantName.from_ast(node) if node.type == :const

        symbol_value(node)&.to_s&.delete_prefix('::')
      end

      # @param node [::Parser::AST::Node]
      # @return [String]
      def comments_for(node)
        (@source.comments_for(node) || '').chomp
      end
    end
  end
end
