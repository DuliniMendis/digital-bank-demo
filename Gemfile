# frozen_string_literal: true

source 'https://rubygems.org'

# Any Ruby from 3.3 onwards will do, because that is the oldest version the
# gems in Gemfile.lock support. No exact version is pinned, so a version
# manager uses whichever Ruby is already installed.
ruby '>= 3.3'

# CSV parsing used to be part of Ruby itself. Since Ruby 3.4 it is a
# separate gem that has to be listed here.
gem 'csv'

# Sinatra is the web framework, Puma is the server it runs on, and rackup
# provides the command that starts it.
gem 'puma'
gem 'rackup'
gem 'sinatra'

group :development, :test do
  gem 'rack-test'
  gem 'rspec', '~> 3.13'
  gem 'rubocop', require: false
  gem 'rubocop-rspec', require: false
end
