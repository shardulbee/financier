# typed: ignore

source 'https://rubygems.org' do
  gem "cli-ui"
  gem "shopify-money"
  gem "dotenv"
  gem "oauth2"
  gem "faraday"
  gem "faraday_middleware"
  gem 'sorbet-runtime'
  gem 'tzinfo'
  gem 'sorbet-struct-comparable'
  gem 'ofx', git: 'https://github.com/annacruz/ofx'

  group :development do
    gem 'sorbet', :group => :development
    gem "pry-byebug"
    gem "pry"
  end

  group :test do
    gem 'webmock'
    gem 'mocha'
    gem 'simplecov', require: false
    gem 'minitest-focus'
    gem 'rake'
  end
end
