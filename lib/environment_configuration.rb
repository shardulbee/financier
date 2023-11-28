# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module EnvironmentConfiguration
  include(Kernel)
  extend(T::Helpers)
  extend(T::Sig)

  class Environment < T::Enum
    enums do
      Test = new
      Production = new
    end
  end

  sealed!
  abstract!

  sig {params(environment: String).returns(EnvironmentConfiguration)}
  def self.get(environment)
    deserialized_environment = Environment.deserialize(environment)
    case deserialized_environment
    when Environment::Test
      Test.new
    when Environment::Production
      Production.new
    else
      T.absurd(deserialized_environment)
    end
  end

  sig {abstract.returns(String)}
  def qfx_dir; end

  sig {abstract.returns(String)}
  def journal_path; end

  sig {abstract.returns(String)}
  def splitwise_api_key; end

  sig {abstract.returns(String)}
  def beeminder_api_key; end

  sig {abstract.returns(String)}
  def journal_dir; end

  class Production
    extend(T::Sig)
    include(EnvironmentConfiguration)

    sig {override.returns(String)}
    def qfx_dir
      File.expand_path('~/Downloads/')
    end

    sig {override.returns(String)}
    def journal_path
      File.expand_path('~/src/github.com/shardulbee/finances/hledger.journal')
    end

    sig {override.returns(String)}
    def journal_dir
      File.expand_path('~/src/github.com/shardulbee/finances/')
    end

    sig {override.returns(String)}
    def splitwise_api_key
      T.must(ENV['SPLITWISE_API_KEY'])
    end

    sig {override.returns(String)}
    def beeminder_api_key
      T.must(ENV['BEEMINDER_TOKEN'])
    end
  end

  class Test
    extend(T::Sig)
    include(EnvironmentConfiguration)

    sig {override.returns(String)}
    def qfx_dir
      File.expand_path('../../data', __FILE__)
    end

    sig {override.returns(String)}
    def journal_path
      File.expand_path('../../data/hledger.journal', __FILE__)
    end

    sig {override.returns(String)}
    def journal_dir
      File.expand_path('../../data', __FILE__)
    end

    sig {override.returns(String)}
    def splitwise_api_key
      raise NotImplementedError.new('Splitwise cannot be called from testmode.')
    end

    sig {override.returns(String)}
    def beeminder_api_key
      raise NotImplementedError.new('Beeminder cannot be called from testmode.')
    end
  end
end
