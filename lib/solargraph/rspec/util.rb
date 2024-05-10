# frozen_string_literal: true

# Credits: This file is a copy of the file from the solargraph-rspec gem

# rubocop:disable Naming/MethodParameterName
module Solargraph
  module Rspec
    # Utility methods for building pins and references.
    module Util
      def self.build_public_method( # rubocop:disable Metrics/MethodLength
        ns,
        name,
        types: nil,
        location: nil,
        comments: [],
        attribute: false,
        scope: :instance
      )
        opts = {
          name: name,
          location: location,
          closure: ns,
          scope: scope,
          attribute: attribute,
          comments: []
        }

        comments << "@return [#{types.join(",")}]" if types

        opts[:comments] = comments.join("\n")

        Solargraph::Pin::Method.new(**opts)
      end

      def self.build_module_include(ns, module_name, location)
        Solargraph::Pin::Reference::Include.new(
          closure: ns,
          name: module_name,
          location: location
        )
      end

      def self.build_module_extend(ns, module_name, location)
        Solargraph::Pin::Reference::Extend.new(
          closure: ns,
          name: module_name,
          location: location
        )
      end

      def self.dummy_location(path)
        Solargraph::Location.new(
          File.expand_path(path),
          Solargraph::Range.from_to(0, 0, 0, 0)
        )
      end

      # @param ast [Parser::AST::Node]
      def self.build_location(ast, path)
        Solargraph::Location.new(
          File.expand_path(path),
          Solargraph::Range.from_to(
            ast.location.first_line,
            ast.location.column,
            ast.location.last_line,
            ast.location.last_column
          )
        )
      end

      def self.method_return(path, type)
        Solargraph::Pin::Reference::Override.method_return(path, type)
      end
    end
  end
end
# rubocop:enable Naming/MethodParameterName
