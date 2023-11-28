# typed: strict
# frozen_string_literal: true

require 'money'
require 'ofx'
require 'sorbet-runtime'

require 'import/source'
require 'import/transaction'

module Import
  class Ofx
    extend(T::Sig)
    include(Source)

    # TODO: make this support multiple accounts to handle scenarios where bank allows you to pull multiple transactions in a single ofx file
    sig { params(path: String).void }
    def initialize(path:)
      @path = path
      @ofx = T.let(OFX(path), OFX::Parser::OFX102)
    end

    sig { override.returns(Balance) }
    def balance
      Balance.new(
        amount: Money.new(@ofx.account.balance.amount),
        as_of: @ofx.account.balance.posted_at.to_date,
        account: account
      )
    end

    sig { override.returns(T::Array[Transaction]) }
    def transactions
      @ofx.account.transactions.map do |ofx_transaction|
        Transaction.new(
          payee: ofx_transaction.name.gsub(/[ \t]+/, ' '),
          transaction_id: ofx_transaction.fit_id,
          account: account,
          amount: Money.new(ofx_transaction.amount),
          date: ofx_transaction.posted_at.to_date,
          kind: Transaction::Kind.deserialize(ofx_transaction.type.to_s)
        )
      end
    end

    sig { returns(String) }
    def inspect
      "<Transactions originating from #{@path} for account #{account.serialize}>"
    end

    sig { override.returns(Account) }
    def account
      Account.deserialize(@ofx.account.id)
    end
  end
end
