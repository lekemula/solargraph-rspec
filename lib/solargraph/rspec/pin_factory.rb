# frozen_string_literal: true

# Credits: This file is a copy of the file from the solargraph-rspec gem

module Solargraph
  module Rspec
    # Factory class for building pins and references.
    module PinFactory
      # def self.build_public_method(
      #   ns,
      #   name,
      #   types: nil,
      #   location: nil,
      #   comments: [],
      #   attribute: false,
      #   scope: :instance
      # )
      #   opts = {
      #     name: name,
      #     location: location,
      #     closure: ns,
      #     scope: scope,
      #     attribute: attribute,
      #     comments: []
      #   }

      #   comments << "@return [#{types.join(",")}]" if types

      #   opts[:comments] = comments.join("\n")

      #   Solargraph::Pin::Method.new(**opts)
      # end

      # def self.build_module_include(ns, module_name, location)
      #   Solargraph::Pin::Reference::Include.new(
      #     closure: ns,
      #     name: module_name,
      #     location: location
      #   )
      # end

      # def self.build_module_extend(ns, module_name, location)
      #   Solargraph::Pin::Reference::Extend.new(
      #     closure: ns,
      #     name: module_name,
      #     location: location
      #   )
      # end

      # def self.dummy_location(path)
      #   Solargraph::Location.new(
      #     File.expand_path(path),
      #     Solargraph::Range.from_to(0, 0, 0, 0)
      #   )
      # end

      # @param ast [RubyVM::AbstractSyntaxTree::Node]
      # @see [RubyVM::AbstractSyntaxTree::NodeWrapper] - for why we need -1 for lineno
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
      def self.build_location(location_range, path)
        Solargraph::Location.new(
          File.expand_path(path),
          location_range
        )
      end

      # def self.method_return(path, type)
      #   Solargraph::Pin::Reference::Override.method_return(path, type)
      # end
    end
  end
end
