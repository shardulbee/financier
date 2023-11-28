# typed: true
# frozen_string_literal: true

require_relative 'test_helper'
require 'import/transaction'

module Import
	class AccountTest < Minitest::Test
		def test_transaction_account_to_ledger_account_mapping
    	assert_equal 'Assets:Checking:TD', Import::Account::TDChecking.ledger_account
    	assert_equal 'Liabilities:InfiniteVisa', Import::Account::TDCreditNew.ledger_account
    	assert_equal 'Liabilities:LOC', Import::Account::TDLoc.ledger_account
    	assert_equal 'Assets:Reimbursements:Splitwise:Jacinthe', Import::Account::SplitwiseJacinthe.ledger_account
		end
	end

	class KindTest < Minitest::Test
		def test_destination_ledger_account
    	assert_equal 'expenses:unknown', Import::Transaction::Kind::Debit.destination_ledger_account
    	assert_equal 'income:unknown', Import::Transaction::Kind::Credit.destination_ledger_account
    	assert_nil Import::Transaction::Kind::Assertion.destination_ledger_account
		end
	end

	class TransactionTest < Minitest::Test
		def test_full_id
			transaction = Import::Transaction.new(
				transaction_id: 'txn_123',
				account: Import::Account::TDChecking,
				payee: 'test payee',
				amount: Money.new(420),
				date: Date.today,
				kind: Import::Transaction::Kind::Credit,
			)
			expected = "#{transaction.account.serialize}.#{transaction.transaction_id}"
			assert_equal expected, transaction.full_id
		end
	end
end
