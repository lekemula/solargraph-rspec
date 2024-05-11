# Solargraph::Rspec - A Solargraph plugin for better RSpec support

![Tests](https://github.com/lekemula/solargraph-rspec/actions/workflows/ruby.yml/badge.svg)
[![codecov](https://codecov.io/gh/lekemula/solargraph-rspec/graph/badge.svg?token=FH7ER8ZDPW)](https://codecov.io/gh/lekemula/solargraph-rspec)


RSpec is a testing framework of choice for many Ruby developers. But at the same time is highly dynamic and heavily relying on metaprogramming making it hard to provide accurate code completion and type inference. 

This gem aims to provide a better support for RSpec in Solargraph and it supports the following features:
  - `describe` and `it` methods completion
  - memoized `let` and `let!` methods completion 
  - implicit and explicit `subject` methods
  - `described_class` with appropriate type inference
  - `RSpec::Matchers` methods completion
  - and more to come...

  ![solargraph-rspec_smaller](https://github.com/lekemula/solargraph-rspec/assets/9197495/66f86e5b-258e-4d8c-8a64-0685d15ece00)

## Installation

###  Install `solargraph` and `solargraph-rspec`

Install the gems from the command line:

```bash
gem install solargraph solargraph-rspec
```

Or add it to your Gemfile:

```ruby
group :development do
  gem 'solargraph' 
  gem 'solargraph-rspec'
end
```

If you add them to your Gemfile, you'll have to tell your IDE plugin to use bundler to load the right version of solargraph.

Add `solargraph-rspec` to your `.solargraph.yml` and remove the `spec` directory from the `exclude` list.

(if you don't have a `.solargraph.yml` in your project root, you can run `solargraph config` to add one)

```diff
@@ -2,7 +2,6 @@
 include:
 - "**/*.rb"
 exclude:
-- spec/**/*
 - test/**/*
 - vendor/**/*
 - ".bundle/**/*"
@@ -18,5 +17,6 @@ formatter:
     only: []
     extra_args: []
 require_paths: []
-plugins: []
+plugins:
+  - solargraph-rspec
 max_files: 5000
```
### Configuration

If you have your own custom `let`-like memoized methods, you can add them to your `.solargraph.yml` file like this:

```yaml
# .solargraph.yml
# ...
rspec:
  let_methods:
    - let_it_be
```

### Gem completions

Solargraph utilizes the YARD documentation to provide code completion. If you want to have completion for gems in your project, you can generate YARD documentation for them ([Read more](https://solargraph.org/guides/yard)).

Run `yard gems` to generate documentation for your installed gems.

Run `yard config --gem-install-yri` to generate YARD documentation automatically when you install new gems.

## Acknowledgements

This gem is inspired by the [solargraph-rails](https://github.com/iftheshoefritz/solargraph-rails) which gave me an idea of how to extend Solargraph with custom features and provided me with simple and very understandable test suite which helped me to get started with playing around with Solargraph. 

In fact, most of the code I initially wrote on [a fork](https://github.com/lekemula/solargraph-rails/tree/rspec-support) of it, but then I realized that it would make more sense to extract it into a separate gem where it could be used by non-Rails projects as well.

It also goes without saying that the Solargraph gem itself is a great tool that it has helped me a lot in my daily work and I'm very grateful to [@castwide](https://github.com/castwide) for creating it and maintaining it. :heart:

It's codebase IMO is an exemplary of how Ruby code written in a very simple POROs without any wild metaprogramming magic and supplemented with YARDocs, for such a complex tools can be very readable and understandable even for a total newbie like me in this domain!

## Contributing

### Bug Reports and Feature Requests

[GitHub Issues](https://github.com/lekemula/solargraph-rspec/issues) are the best place to ask questions, report problems, and suggest improvements.

### Development

Code contributions are always appreciated. Feel free to fork the repo and submit pull requests. Check for open issues that could use help. Start new issues to discuss changes that have a major impact on the code or require large time commitments.

Contributing is easy:
1. Create a fork and clone it
2. Run `bundle install` to install dependencies
3. Run `yard gems` to generate YARD documentation for your installed gems
4. Run `bundle exec spec` to run the tests
5. Introduce your awesome changes
6. Ensure they are well covered with tests
7. Record your changes in the [CHANGELOG.md](./CHANGELOG.md)
7. Submit a pull request :rocket:

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

