# typed: strict
# frozen_string_literal: true

require 'date'
require 'faraday'
require 'faraday_middleware'
require 'money'
require 'json'
require 'sorbet-runtime'

module Beeminder
  class Client
    extend(T::Sig)

    BASE_SITE = 'https://www.beeminder.com/api/v1/users/shardy/goals/'

    sig { params(auth_token: String).void }
    def initialize(auth_token:)
      @auth_token = auth_token

      @connection = T.let(Faraday.new(url: BASE_SITE) do |conn|
        conn.request       :json
        conn.response      :json, :content_type => /\bjson$/
      end, Faraday::Connection)
    end

    sig { params(description: String, amount: Money, date: Date).returns(Faraday::Response) }
    def submit_expense(description:, amount:, date:)
      @connection.post(
        submit_data_path('blowads'),
        default_params.merge({
          comment: description,
          value: amount.to_f,
          daystamp: date.strftime('%Y%m%d')
        })
      )
    end

    sig {returns(T::Boolean)}
    def incremented_trackwads_today?
      response = @connection.get(
        submit_data_path('trackwads'),
        default_params.merge({
          count: 1
        })
      )
      return true if Date.strptime(response.body.first['daystamp'], '%Y%m%d') == Date.today
      false
    end

    sig { returns(T.nilable(Faraday::Response)) }
    def increment_trackwads
      return if incremented_trackwads_today?
      @connection.post(
        submit_data_path('trackwads'),
        default_params.merge({
          value: 1,
          daystamp: Date.today.strftime('%Y%m%d')
        })
      )
    end

    private

    sig { params(goal: String).returns(String) }
    def submit_data_path(goal)
      "#{goal}/datapoints.json"
    end

    sig { returns({ auth_token: String })}
    def default_params
      { auth_token: @auth_token }
    end
  end
end
