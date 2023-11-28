# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module Ledger
  class BookEntry
    extend(T::Sig)

    sig { returns(T.nilable(Money)) }
    attr_reader :balance_assertion

    sig { returns(Money) }
    attr_reader :amount

    sig { returns(T.nilable(String)) }
    attr_reader :id

    sig { returns(String) }
    attr_reader :account

    sig do
      params(
        account: String,
        amount: Money,
        balance_assertion: T.nilable(Money),
        id: T.nilable(String)
      ).void
    end
    def initialize(account:, amount:, balance_assertion: nil, id: nil)
      @account = account
      @amount = amount
      @balance_assertion = balance_assertion
      @id = id
    end

    sig { params(transaction: Import::Transaction).returns(T::Boolean) }
    def looks_like?(transaction)
      return false unless id.nil?
      account == transaction.account.ledger_account &&
        amount == transaction.amount
    end

    sig { returns(T::Boolean) }
    def default_book?
      %w(income:unknown expenses:unknown).include?(account)
    end

    sig { returns(T::Boolean) }
    def real_account_book?
      Import::Account.real_accounts.map(&:ledger_account).include?(account)
    end

    sig { params(other: BookEntry).returns(T::Boolean) }
    def ==(other)
      T.must(amount == other.amount &&
        account == other.account &&
        balance_assertion == other.balance_assertion &&
        id == other.id)
    end

    sig { returns(String) }
    def to_s
      account_string = "    #{account}"
      amount_string = "  #{amount}"
      balance_assertion_string = if balance_assertion.nil?
        ""
      else
        " = #{balance_assertion}"
      end
      id_string = if id.nil?
        ""
      else
        " ; tid:#{id}"
      end

      "#{account_string}#{amount_string}#{balance_assertion_string}#{id_string}"
    end

    sig do
      params(
        account: T.nilable(String),
        amount: T.nilable(Money),
        balance_assertion: T.nilable(Money),
        id: T.nilable(String)
      ).returns(BookEntry)
    end
    def update(account:nil, amount: nil, balance_assertion: nil, id: nil)
      @account = account unless account.nil?
      @amount = amount unless amount.nil?
      @balance_assertion = balance_assertion unless balance_assertion.nil?
      @id = id unless id.nil?
      self
    end
  end
end
