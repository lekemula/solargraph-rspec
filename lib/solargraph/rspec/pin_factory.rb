# frozen_string_literal: true

# Credits: This file was originally copied and adapted from the solargraph-rails gem.

module Solargraph
  module Rspec
    # Factory class for building pins and references.
    module PinFactory
      # @param namespace [Solargraph::Pin::Namespace]
      # @param name [String]
      # @param types [Array<String>, nil]
      # @param [Parser::AST::Node, nil] node
      # @param location [Solargraph::Location, nil]
      # @param comments [Array<String>]
      # @param attribute [Boolean]
      # @param scope [:instance, :class] # rubocop:disable YARD/TagTypeSyntax
      # @return [Solargraph::Pin::Method]
      def self.build_public_method(
        namespace,
        name,
        types: nil,
        location: nil,
        comments: [],
        attribute: false,
        scope: :instance,
        node: nil
      )
        opts = {
          name: name,
          location: location,
          closure: namespace,
          scope: scope,
          attribute: attribute,
          comments: [],
          node: node
        }

        comments << "@return [#{types.join(",")}]" if types

        opts[:comments] = comments.join("\n")

        Solargraph::Pin::Method.new(**opts)
      end

      # @param namespace [Solargraph::Pin::Namespace]
      # @param module_name [String]
      # @param location [Solargraph::Location]
      # @return [Solargraph::Pin::Reference::Include]
      def self.build_module_include(namespace, module_name, location)
        Solargraph::Pin::Reference::Include.new(
          closure: namespace,
          name: module_name,
          location: location
        )
      end

      # @param namespace [Solargraph::Pin::Namespace]
      # @param module_name [String]
      # @param location [Solargraph::Location]
      # @return [Solargraph::Pin::Reference::Extend]
      def self.build_module_extend(namespace, module_name, location)
        Solargraph::Pin::Reference::Extend.new(
          closure: namespace,
          name: module_name,
          location: location
        )
      end

      # @param path [String]
      # @return [Solargraph::Location]
      def self.dummy_location(path)
        Solargraph::Location.new(
          File.expand_path(path),
          Solargraph::Range.from_to(0, 0, 0, 0)
        )
      end

      # Given the following code, Solargraph::Parser.node_range returns the following range for block ast:
      #
      # some_method_with_block do
      # ^ - block start
      # end
      # ^ - block end
      #
      # Instead we want the range to be:
      #
      # some_method_with_block do
      #                        ^ - block start
      # end
      # ^ - block end
      #
      # @param ast [::Parser::AST::Node]
      # @return [Solargraph::Range]
      def self.build_location_range(ast)
        if ast.type == :block
          method_range = Solargraph::Parser.node_range(ast.children[0])
          full_block_range = Solargraph::Parser.node_range(ast)

          Solargraph::Range.from_to(
            method_range.ending.line,
            method_range.ending.character,
            full_block_range.ending.line,
            full_block_range.ending.character
          )
        else
          Solargraph::Parser.node_range(ast)
        end
      end

      # @param location_range [Solargraph::Range]
      # @param path [String]
      # @return [Solargraph::Location]
      def self.build_location(location_range, path)
        Solargraph::Location.new(
          File.expand_path(path),
          location_range
        )
      end
    end
  end
end
