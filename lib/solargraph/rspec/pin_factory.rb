# frozen_string_literal: true

# Credits: This file is a copy of the file from the solargraph-rspec gem

module Solargraph
  module Rspec
    # Factory class for building pins and references.
    module PinFactory
      # @param namespace [Solargraph::Pin::Namespace]
      # @param name [String]
      # @param types [Array<String>]
      # @param location [Solargraph::Location]
      # @param comments [Array<String>]
      # @param attribute [Boolean]
      # @param scope [:instance, :class]
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
      # @param name [String]
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

      # @param ast [RubyVM::AbstractSyntaxTree::Node]
      # @see [RubyVM::AbstractSyntaxTree::NodeWrapper] - for why we need -1 for lineno
      # @return [Solargraph::Range]
      def self.build_location_range(ast)
        Solargraph::Range.from_to(
          ast.first_lineno - 1,
          ast.first_column,
          ast.last_lineno - 1,
          ast.last_column
        )
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
