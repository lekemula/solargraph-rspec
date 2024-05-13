# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- 

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
