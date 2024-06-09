# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]


## [0.2.1] - 2024-06-09

### Added

- Documentation for `RSpec::ExampleGroups` DSL methods like `it`, `fit`, `example` etc.

### Fixed

- Fix nameless `subject` method completion inside nested `context` blocks
- (Hack-ish) Fix `described_class` type collision when `RSpec.describe SomeClassWithoutNamespace`

## [0.2.0] - 2024-05-20

### Added

- `let` and `subject` type inference 🚀 (Resolves: [Issue #1](https://github.com/lekemula/solargraph-rspec/issues/1))

### Changed

- Migrate from `parser` gem to using ruby's built-in RubyVM::AbstractSyntaxTree ([see why](https://github.com/castwide/solargraph/issues/522#issuecomment-993016664))

### Fixed

- Fix subject without name block completion: `subject { ... }`
- Fix subject return class overlap with `Rspec::ExampleGroups::` when class has no namespace

## [0.1.1] - 2024-05-13

### Removed
- Removed redundant `active_support` dependency ([Issue #2](https://github.com/lekemula/solargraph-rspec/issues/2))

### Fixed
- Fixed completions inside `subject` and `subject!` blocks

## [0.1.0] - 2024-05-11 (First Release 🎉)

### Added

- `describe` and `it` methods completion
- memoized `let` and `let!` methods completion 
- implicit and explicit `subject` methods
- `described_class` with appropriate type inference
- `RSpec::Matchers` methods completion
- Completes normal ruby methods within `describe/context` blocks
- RSpec DSL suggestions (eg. `it`, `describe`, `fit`.. etc.)
