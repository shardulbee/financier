# typed: true
# frozen_string_literal: true

require_relative 'test_helper'
require 'ledger/journal'
require 'import/transaction'

module Ledger
  class JournalTest < Minitest::Test
    DESCRIPTION = 'ACCOUNT TRANSFER'
    ACCOUNT = Import::Account::TDChecking
    AMOUNT = Money.new(1)
    DATE = Date.today
    KIND = Import::Transaction::Kind::Credit
    ID = 'abc'

    TRANSACTION = Import::Transaction.new(
      account: ACCOUNT,
      amount: AMOUNT,
      payee: DESCRIPTION,
      date: DATE,
      kind: KIND,
      transaction_id: ID
    )

    def test_empty_true
      assert Journal.new([]).empty?
    end

    def test_empty_false
      refute Journal.new([stub]).empty?
    end

    def test_length
      assert_equal 0, Journal.new([]).length
      assert_equal 1, Journal.new([stub]).length
      assert_equal 2, Journal.new([stub, stub]).length
    end

    def test_to_s
      journal = Journal.new([])
      journal.import_transaction(TRANSACTION)
      expected = <<-JOURNAL
#{journal.journal_entries.last.to_s}
      JOURNAL
      assert_equal expected, journal.to_s
    end

    def test_accounts
      journal = Journal.new([])
      journal.import_transaction(TRANSACTION)
      expected = [
        TRANSACTION.source_ledger_account,
        TRANSACTION.destination_ledger_account
      ]
      assert_equal expected, journal.accounts
    end

    def test_add_transaction_does_nothing_if_journal_entry_with_id_already_exists
      journal = Journal.new([stub(book_entry_ids: [TRANSACTION.full_id])])
      journal.import_transaction(TRANSACTION)
      assert_equal 1, journal.length
    end

    def test_add_transaction_does_nothing_if_we_can_associate_transaction_with_existing_journal_entry
      mock_journal_entry = mock
      mock_journal_entry.expects(:associate).with(TRANSACTION).returns(true)
      mock_journal_entry.stubs(:book_entry_ids).returns([])

      journal = Journal.new([mock_journal_entry])
      journal.import_transaction(TRANSACTION)
      assert_equal 1, journal.length
    end

    def test_add_transaction_adds_transaction_if_it_doesnt_already_exist
      mock_journal_entry = mock
      mock_journal_entry.expects(:associate).with(TRANSACTION).returns(false)
      mock_journal_entry.stubs(:book_entry_ids).returns([])

      expected_journal_entry = JournalEntry.new(
        date: DATE,
        description: DESCRIPTION,
        book_entries: [
          BookEntry.new(account: TRANSACTION.source_ledger_account, amount: AMOUNT, id: TRANSACTION.full_id),
          BookEntry.new(account: TRANSACTION.destination_ledger_account, amount: -AMOUNT)
        ]
      )

      journal = Journal.new([mock_journal_entry])
      journal.import_transaction(TRANSACTION)
      assert_equal 2, journal.length
      assert_equal expected_journal_entry, journal.journal_entries.last
    end

    # def test_add_transaction_adds_transaction_if_it_is_a_balance_assertion
    #   transaction = Import::Transaction.new(
    #     account: ACCOUNT,
    #     amount: AMOUNT,
    #     payee: DESCRIPTION,
    #     date: DATE,
    #     kind: Import::Transaction::Kind::Assertion,
    #     transaction_id: ID
    #   )

    #   mock_journal_entry = mock
    #   mock_journal_entry.expects(:associate).with(transaction).returns(false)
    #   mock_journal_entry.stubs(:book_entry_ids).returns([])

    #   expected_journal_entry = JournalEntry.new(
    #     date: DATE,
    #     description: DESCRIPTION,
    #     book_entries: [
    #       BookEntry.new(
    #         account: transaction.source_ledger_account,
    #         amount: Money.new(0),
    #         balance_assertion: transaction.amount,
    #         id: transaction.full_id
    #       )
    #     ]
    #   )

    #   journal = Journal.new([mock_journal_entry])
    #   journal.import_transaction(transaction)
    #   assert_equal 2, journal.length
    #   assert_equal expected_journal_entry, journal.journal_entries.last
    # end
  end
end
