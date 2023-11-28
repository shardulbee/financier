# typed: strict
# frozen_string_literal: true

require 'money'
require 'sorbet-runtime'

require 'import/source'
require 'import/transaction'
require 'splitwise/client'

module Import
  class SplitwiseSource
    extend(T::Sig)
    include(Import::Source)

    class Friend < T::Enum
    	extend(T::Sig)

    	enums do
    		Jacinthe = new(9239057)
    	end

    	sig { returns(Account) }
    	def account
    		case self
    		when Jacinthe
    			Account::SplitwiseJacinthe
    		end
    	end
    end

    sig { params(client: Splitwise::Client, friend: Friend).void }
    def initialize(client, friend)
    	@client = client
    	@friend = friend
    end

    sig { override.returns(Balance) }
    def balance
      Balance.new(
        account: account,
        amount: @client.get_balance(@friend.serialize.to_i),
        as_of: Date.today
      )
    end

    sig {override.returns(Account)}
    def account
      @friend.account
    end

    sig { override.returns(T::Array[Transaction]) }
    def transactions
    	@client.list_expenses(@friend.serialize.to_i).map do |expense|
    		raise "You have an expense between 3 people that we don't know how to handle yet." if expense.expense_shares.length > 2
    		shared_with = T.must(expense.expense_shares.find { |share| !share.mine? && Friend.deserialize(share.user_id) == @friend })
        mine = T.must(expense.expense_shares.find { |share| share.mine? })

    		Transaction.new(
			    transaction_id: expense.id.to_s,
			    account: @friend.account,
			    payee: expense.description,
			    amount: mine.paid - mine.owes,
			    date: expense.date,
			    kind: expense.cost < 0 ? Transaction::Kind::Credit : Transaction::Kind::Debit,
  			)
    	end
    end
  end
end
