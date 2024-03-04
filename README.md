# WIP!!! Solargraph::Rspec - A Solargraph plugin for better RSpec support

RSpec is a testing framework of choice for many Ruby developers. But at the same time is highly dynamic and heavily relying on metaprogramming making it hard to provide accurate code completion and type inference. 

This gem aims to provide a better support for RSpec in Solargraph and it supports the following features:
  - `describe` and `it` methods completion
  - memoized `let` and `let!` methods completion 
  - implicit/explicit `subject` and `subject!` methods
  - `described_class` with appropriate type inference
  - `RSpec::Matchers` methods completion
  
TODO: Add a gif showing the features in action

## Installation

> [!IMPORTANT]
> As this gem is a WIP and depends on [unmerged changes](https://github.com/castwide/solargraph/compare/master...lekemula:solargraph:rspec-support?expand=1) in Solargraph, at the moment you need to use the forked version from [lekemula/solargraph@rspec-support](https://github.com/lekemula/solargraph/tree/rspec-support) branch. Once merged, you can install it from the official repository.

###  Install `solargraph` and `solargraph-rspec`

Install the gems from the command line:

```bash
git clone https://github.com/lekemula/solargraph.git
cd solargraph && git checkout rspec-support && gem build
gem install solargraph-<current-version>.gem


git clone https://github.com/lekemula/solargraph-rspec.git
cd solargraph-rspec && gem build
gem install solargraph-rspec-<current-version>.gem
```

Or add it to your Gemfile:

```ruby
group :development do
  gem 'solargraph', github: 'lekemula/solargraph', branch: 'rspec-support'
  gem 'solargraph-rspec', github: 'lekemula/solargraph-rspec'
end
```

If you add them to your Gemfile, you'll have to tell your IDE plugin to use bundler to load the right version of solargraph.

Add `solargraph-rspec` to your `.solargraph.yml`

(if you don't have a `.solargraph.yml` in your project root, you can run `solargraph config` to add one)

```yaml
# .solargraph.yml
plugins:
  - solargraph-rspec

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

### Documenting Your Gems

Run `yard gems` to generate documentation for your installed gems.

Run `yard config --gem-install-yri` to generate YARD documentation automatically when you install new gems.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

### Bug Reports and Feature Requests

[GitHub Issues](https://github.com/lekemula/solargraph-rspec/issues) are the best place to ask questions, report problems, and suggest improvements.

### Development

Code contributions are always appreciated. Feel free to fork the repo and submit pull requests. Check for open issues that could use help. Start new issues to discuss changes that have a major impact on the code or require large time commitments.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


