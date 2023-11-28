# typed: strict
# frozen_string_literal: true

require 'faraday'
require 'faraday_middleware'
require 'json'
require 'money'
require 'oauth2'
require 'sorbet-runtime'
require 'sorbet-struct-comparable'
require 'tzinfo'

module Splitwise
  InvalidExpenseShareError = Class.new(StandardError)
  SHARDUL_SPLITWISE_ID = 1570407

  class ExpenseShare < T::Struct
    extend(T::Sig)
    include(T::Struct::ActsAsComparable)

    const :user_id, Integer
    const :paid, Money
    const :owes, Money

    sig { params(from: T::Hash[T.untyped, T.untyped]).returns(ExpenseShare) }
    def self.deserialize(from)
      new(
        user_id: from['user']['id'],
        paid: Money.new(from['paid_share']),
        owes: Money.new(from['owed_share'])
      )
    end

    sig { returns(T::Boolean) }
    def mine?
      user_id == SHARDUL_SPLITWISE_ID
    end
  end

  class SubmittedExpense < T::Struct
    extend(T::Sig)
    include(T::Struct::ActsAsComparable)

    const :id, Integer
    const :date, Date
    const :cost, Money
    const :description, String
    const :expense_shares, T::Array[ExpenseShare]

    sig { params(from: T::Hash[T.untyped, T.untyped]).returns(SubmittedExpense) }
    def self.deserialize(from)
      expense_shares = from['users'].map { |share| ExpenseShare.deserialize(share) }
      new(
        id: from['id'],
        date: TZInfo::Timezone.get('America/Toronto').to_local(Time.parse(from['date'])).to_date,
        cost: Money.new(from['cost']),
        description: from['description'],
        expense_shares: expense_shares
      )
    end
  end

  class Expense < T::Struct
    extend(T::Sig)
    include(T::Struct::ActsAsComparable)

    const :date, Date
    const :cost, Money
    const :description, String
    const :expense_shares, T::Array[ExpenseShare]

    sig { returns(T::Hash[Symbol, T.any(String, T::Boolean, Integer)]) }
    def serialize
      serialized = T.let({}, T::Hash[Symbol, T.any(String, T::Boolean, Integer)])
      expense_shares.each_with_index do |share, i|
        serialized = serialized.merge({
          "users__#{i}__user_id" => share.user_id,
          "users__#{i}__paid_share" => share.paid.to_s,
          "users__#{i}__owed_share" => share.owes.to_s,
        })
      end
      serialized.merge({
        cost: cost.to_s,
        payment: false,
        description: description,
        group_id: 0,
        date: date.to_time.to_datetime.iso8601,
        currency_code: 'CAD'
      }).transform_keys(&:to_sym)
    end

    sig { returns(T::Boolean) }
    def valid?
      cost == expense_shares.sum(&:paid) &&
        expense_shares.sum(&:paid) == expense_shares.sum(&:owes)
    end
  end

  class Client
    extend(T::Sig)

    BASE_SITE = 'https://secure.splitwise.com/api/v3.0'

    CREATE_EXPENSE_ENDPOINT = 'create_expense'
    LIST_EXPENSES_ENDPOINT = 'get_expenses'
    GET_FRIEND_ENDPOINT = 'get_friend'

    sig { params(auth_token: String).void }
    def initialize(auth_token:)
      @connection = T.let(Faraday.new(BASE_SITE) do |conn|
        conn.request       :json
        conn.request       :authorization, 'Bearer', auth_token
        conn.response      :json, :content_type => /\bjson$/
      end, Faraday::Connection)
    end

    sig { params(friend_id: Integer).returns(T::Array[SubmittedExpense]) }
    def list_expenses(friend_id)
      toret = @connection.get(LIST_EXPENSES_ENDPOINT,  friend_id: friend_id, limit: 100).body['expenses'].map do |expense|
        next if expense['deleted_at']
        SubmittedExpense.deserialize(expense)
      end.compact
    end

    sig { params(friend_id: Integer).returns(Money) }
    def get_balance(friend_id)
      balances = @connection.get("#{GET_FRIEND_ENDPOINT}/#{friend_id}").body['friend']['balance']
      raise "Too many balances in the response for #get_balance for friend: #{friend_id}" if balances.length > 1

      Money.new(balances.first['amount'])
    end

    sig { params(expense: Expense).void }
    def create_expense(expense)
      raise InvalidExpenseShareError, \
        "The following expense has unbalanced `ExpenseShare`s: #{expense.serialize}" unless expense.valid?
      resp = @connection.post(CREATE_EXPENSE_ENDPOINT, expense.serialize)
    end
  end
end
