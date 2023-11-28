# typed: strict
# frozen_string_literal: true

require 'import/ofx'
require 'import/splitwise_source'

require 'splitwise/client'

module Import
  module Helpers
    extend(T::Sig)

    sig {params(config: EnvironmentConfiguration).returns(T::Array[Transaction])}
    def self.import_transactions(config)
      if config.is_a?(EnvironmentConfiguration::Test)
        self.import_ofx_transactions(config.qfx_dir)
      elsif config.is_a?(EnvironmentConfiguration::Production)
        self.import_ofx_transactions(config.qfx_dir) |
          self.import_jacinthe_transactions(config.splitwise_api_key)
      else
        T.absurd(config)
      end
    end

    sig {params(auth_token: String).returns(Balance)}
    def self.import_jacinthe_balance(auth_token)
      Import::SplitwiseSource.new(
        Splitwise::Client.new(auth_token: auth_token),
        Import::SplitwiseSource::Friend::Jacinthe
      ).balance
    end

    sig {params(directory: String).returns(T::Array[Balance])}
    def self.import_ofx_balances(directory)
      files = Dir.glob(File.join(File.expand_path(directory), '*.qfx')).sort
      files.map do |ofx_filename|
        Import::Ofx.new(path: ofx_filename).balance
      end
    end

    sig {params(directory: String).void}
    def self.delete_ofx_files(directory)
      files = Dir.glob(File.join(File.expand_path(directory), '*.qfx')).sort
      files.each do |ofx_filename|
        File.delete(ofx_filename)
      end
    end

    sig {params(auth_token: String).returns(T::Array[Transaction])}
    private_class_method def self.import_jacinthe_transactions(auth_token)
      Import::SplitwiseSource.new(
        Splitwise::Client.new(auth_token: auth_token),
        Import::SplitwiseSource::Friend::Jacinthe
      ).transactions
    end


    sig {params(directory: String).returns(T::Array[Transaction])}
    private_class_method def self.import_ofx_transactions(directory)
      files = Dir.glob(File.join(File.expand_path(directory), '*.qfx')).sort
      files.flat_map do |ofx_filename|
        Import::Ofx.new(path: ofx_filename).transactions
      end
    end
  end
end
