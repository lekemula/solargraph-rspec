# Solargraph::Rspec - A [Solargraph](https://solargraph.org/) plugin for better [RSpec](https://rspec.info/) support

[![Gem Version](https://badge.fury.io/rb/solargraph-rspec.svg)](https://badge.fury.io/rb/solargraph-rspec)
![Tests](https://github.com/lekemula/solargraph-rspec/actions/workflows/ruby.yml/badge.svg)
[![codecov](https://codecov.io/gh/lekemula/solargraph-rspec/graph/badge.svg?token=FH7ER8ZDPW)](https://codecov.io/gh/lekemula/solargraph-rspec)


RSpec is a testing framework of choice for many Ruby developers. But at the same time is highly dynamic and heavily relying on metaprogramming making it hard to provide accurate code completion and type inference.

This gem aims to provide better support for RSpec in Solargraph and it supports the following features (completion, jump to definition and type inference 🚀):
  - `describe` and `it` methods
  - memoized `let` and `let!` methods
  - `described_class` with appropriate type inference
  - implicit and explicit `subject` methods
  - one liner syntax helpers `is_expected`, `should` and `should_not` linked to the appropriate subject
  - Core and 3rd party spec helpers & matchers
    - [rspec-mocks](https://github.com/rspec/rspec-mocks)
    - [rspec-rails](https://github.com/rspec/rspec-rails)
    - [webmock](https://github.com/bblimke/webmock)
    - [shoulda-matchers](https://matchers.shoulda.io/)
    - [rspec-sidekiq](https://github.com/wspurgin/rspec-sidekiq)
    - [airborne](https://github.com/brooklynDev/airborne)
  - Custom DSL extensions support (see [Configuration](#configuration) section)
  - "▶ Run RSpec" code lenses for the whole file and every `describe`/`context`/example block (requires a Solargraph version with code lens support)
  - and more to come... ⏲️

![solargraph-rspec-with-types](./doc/images/vim_demo.gif)
![solargraph-rspec-with-types-vs-code](./doc/images/vscode_demo.gif)


## Installation

###  Install `solargraph` and `solargraph-rspec`

Install the gems from the command line:

```bash
gem install solargraph solargraph-rspec
```

Or add it to your Gemfile:

```ruby
group :development do
  gem 'solargraph', require: false
  gem 'solargraph-rspec', require: false
end
```

If you add them to your Gemfile, you'll have to tell your IDE plugin to use bundler to load the right version of solargraph.

Add `solargraph-rspec` to your `.solargraph.yml` as a plugin.

> [!CAUTION]
> To avoid **performance issues**, please keep the `spec/**/*` directory in **exclude** list in the Solargraph configuration.
> That does not actually *exclude* the specs, but rather avoids pre-indexing the specs when Solargraph boots up, and only parses
> the specs on demand when opened in the editor, which is what we usually want.

(if you don't have a `.solargraph.yml` in your project root, you can run `solargraph config` to add one)

```diff
@@ -2,7 +2,6 @@
 include:
 - "**/*.rb"
 exclude:
+- spec/**/*
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

You can customize the plugin behavior in your `.solargraph.yml`:

```yaml
# .solargraph.yml
# ...
rspec:
  # Custom let-like memoized methods (e.g., from rspec-given, test-prof)
  let_methods:
    - let_it_be

  # Custom example-like methods (e.g., from rspec-given)
  example_methods:
    - my_it

  # RSpec helper files to analyze for included modules (shared contexts, custom matchers)
  config_helper_files:
    - spec/spec_helper.rb
    - spec/rails_helper.rb

  # Run code lens commands through Bundler, i.e. `bundle exec rspec ...` (default: false)
  use_bundler: true
  # Bundler executable used when `use_bundler` is enabled (default: bundle)
  bundler_path: bin/bundle
```

### Code lenses

The plugin adds "Run" code lenses on the first line of a spec file (the whole file) and above every `describe`/`context`/example block. They need a Solargraph version with code lens support and an editor that implements the `solargraph.runRspec` client command:

- **VS Code**: the [vscode-solargraph](https://github.com/castwide/vscode-solargraph) extension runs lenses in a terminal or in the Testing view.
- **Neovim** (built-in LSP): show the lenses and implement the command yourself, e.g.:

```lua
-- Start the project's Solargraph when solargraph-rspec is in its bundle
vim.lsp.config("solargraph", {
  cmd = { "bundle", "exec", "solargraph", "stdio" },
  filetypes = { "ruby" },
  root_markers = { "Gemfile", ".git" },
})
vim.lsp.enable("solargraph")

-- Show Solargraph's code lenses
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "solargraph" then
      vim.lsp.codelens.enable(true, { client_id = client.id }) -- Neovim 0.12+
      -- Neovim 0.10/0.11: refresh them yourself instead
      -- vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "TextChanged" }, {
      --   buffer = args.buf,
      --   callback = function() vim.lsp.codelens.refresh({ bufnr = args.buf }) end,
      -- })
    end
  end,
})

-- Run a lens: its first argument holds the rspec command line, e.g. "bundle exec rspec spec/foo_spec.rb:12"
vim.lsp.commands["solargraph.runRspec"] = function(command)
  vim.cmd("botright split | terminal " .. command.arguments[1].command)
  -- or, with vim-dispatch: vim.cmd("Dispatch " .. command.arguments[1].command)
end

vim.keymap.set("n", "<leader>cr", vim.lsp.codelens.run, { desc = "Run code lens" })
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

Contributing is easy - note that this Gem uses 'appraisal' to test against RSpec 3rd party plugins without adding to the main `Gemfile`:
1. Create a fork and clone it
2. Verify tests are green:
   ```sh
   bundle install
   bundle exec appraisal install
   cp .solargraph.yml.example .solargraph.yml
   bundle exec appraisal bundle exec rbs collection update
   bundle exec appraisal bundle exec solargraph gems $(bundle exec appraisal bundle exec ruby -r './lib/solargraph-rspec' -e 'puts Solargraph::Rspec::Gems.gem_names.join(" ")' 2>/dev/null | tail -n1)
   bundle exec appraisal rspec
   ```
3. Introduce your awesome changes
4. Ensure they are well covered with tests
5. Record your changes in the [CHANGELOG.md](./CHANGELOG.md)
6. Submit a pull request :rocket:

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
