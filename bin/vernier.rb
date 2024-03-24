#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'solargraph'
require 'solargraph-rspec'
require 'vernier'
require 'fileutils'
require 'benchmark'

puts <<~MSG
  NOTE: Ensure you have build and installed the latest version of solargraph-rspec
    gem build
    gem install solargraph-rspec-0.0.1.gem
MSG

FileUtils.cp('spec/fixtures/configs/.solargraph-with-rspec.yml', 'spec/fixtures/mastodon/.solargraph.yml')

directory = 'spec/fixtures/mastodon'

api_map = nil
time = Benchmark.measure do
  Vernier.trace(out: 'time_profile.json') do
    api_map = Solargraph::ApiMap.load(directory)
  end
end

puts "Scanned #{directory} (#{api_map.pins.length} pins) in #{time.real} seconds."

FileUtils.rm('spec/fixtures/mastodon/.solargraph.yml')

system('profile-viewer time_profile.json')
