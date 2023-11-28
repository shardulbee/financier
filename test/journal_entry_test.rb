# typed: true
# frozen_string_literal: true

require_relative 'test_helper'
require 'ledger/journal_entry'

module Ledger
  class JournalEntryTest < Minitest::Test
    DESCRIPTION = 'ACCOUNT TRANSFER'
    DATE = Date.today
    TOKEN = 'abc'

    def setup
      ENV['BEEMINDER_TOKEN'] = TOKEN
      ENV['SPLITWISE_API_KEY'] = TOKEN
    end

    def test_associate_false_no_matching_book_entries
      journal_entry = JournalEntry.new(
        date: DATE,
        description: DESCRIPTION,
        book_entries: [stub(looks_like?: false)]
      )
      transaction = Import::Transaction.new(
        account: Import::Account::TDChecking,
        amount: Money.new(1),
        payee: DESCRIPTION,
        date: DATE,
        kind: Import::Transaction::Kind::Credit,
        transaction_id: 'abc'
      )
      refute journal_entry.associate(transaction)
    end

    def test_associate_false_date_and_description_doesnt_match
      journal_entry = JournalEntry.new(
        date: Date.new(2020, 1, 2),
        description: DESCRIPTION,
        book_entries: [stub(looks_like?: true)]
      )
      transaction = Import::Transaction.new(
        account: Import::Account::TDChecking,
        amount: Money.new(1),
        payee: DESCRIPTION + 'a',
        date: Date.new(2020, 1, 1),
        kind: Import::Transaction::Kind::Credit,
        transaction_id: 'abc'
      )
      refute journal_entry.associate(transaction)
    end

    def test_associate_true_if_date_matches_but_description_doesnt
      transaction = Import::Transaction.new(
        account: Import::Account::TDChecking,
        amount: Money.new(1),
        payee: DESCRIPTION + 'a',
        date: Date.new(2020, 1, 1),
        kind: Import::Transaction::Kind::Credit,
        transaction_id: 'abc'
      )
      expected = mock(looks_like?: true)
      expected.expects(:update).with(id: transaction.full_id)
      journal_entry = JournalEntry.new(
        date: Date.new(2020, 1, 1),
        description: DESCRIPTION,
        book_entries: [expected]
      )
      assert journal_entry.associate(transaction)
    end

    def test_associate_true_if_everything_matches
      transaction = Import::Transaction.new(
        account: Import::Account::TDChecking,
        amount: Money.new(1),
        payee: DESCRIPTION,
        date: Date.new(2020, 1, 1),
        kind: Import::Transaction::Kind::Credit,
        transaction_id: 'abc'
      )
      expected = mock(looks_like?: true)
      expected.expects(:update).with(id: transaction.full_id)
      journal_entry = JournalEntry.new(
        date: Date.new(2020, 1, 1),
        description: DESCRIPTION,
        book_entries: [expected]
      )
      assert journal_entry.associate(transaction)
    end

    def test_book_entry_ids
      assert_equal ['abc'], JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [stub(id: 'abc')]
      ).book_entry_ids
    end

    def test_book_entry_ids_removes_nils
      assert_equal ['abc'], JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [stub(id: 'abc'), stub(id: nil)]
      ).book_entry_ids
    end

    def test_accounts_returns_all_accounts_in_journal_entry
      assert_equal ['Expenses', 'Assets'], JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [stub(account: 'Expenses'), stub(account: 'Assets')]
      ).accounts
    end

    def test_to_s
      actual = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [stub(to_s: 'JournalEntryOne'), stub(to_s: 'JournalEntryTwo')]
      ).to_s

      expected = <<-journal.chomp
#{DATE.strftime('%Y-%m-%d')} #{DESCRIPTION}
JournalEntryOne
JournalEntryTwo
      journal

      assert_equal actual, expected
    end

    def test_categorize
      actual = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Account1', amount: Money.new(1)),
          BookEntry.new(account: 'income:unknown', amount: Money.new(-1))
        ]
      )
      expected = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Account1', amount: Money.new(1)),
          BookEntry.new(account: 'Income:Other', amount: Money.new(-1))
        ]
      )

      actual.categorize(account: 'Income:Other')

      assert_equal expected, actual
    end

    def test_categorize_raises_if_there_are_no_book_entries_to_categorize
      actual = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Account1', amount: Money.new(1)),
          BookEntry.new(account: 'Account2', amount: Money.new(-1))
        ]
      )

      assert_raises do
        actual.categorize(account: 'Income:Other')
      end
    end

    def test_categorize_uses_the_right_book_if_it_is_the_first_entry
      actual = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'income:unknown', amount: Money.new(1)),
          BookEntry.new(account: 'Account2', amount: Money.new(-1))
        ]
      )
      expected = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Income:Other', amount: Money.new(1)),
          BookEntry.new(account: 'Account2', amount: Money.new(-1))
        ]
      )

      actual.categorize(account: 'Income:Other')

      assert_equal expected, actual
    end

    def test_changed_false
      refute JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Account1', amount: Money.new(1)),
          BookEntry.new(account: 'income:unknown', amount: Money.new(-1))
        ]
      ).changed?
    end

    def test_changed_true
      journal_entry = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Account1', amount: Money.new(1)),
          BookEntry.new(account: 'income:unknown', amount: Money.new(-1))
        ]
      )
      journal_entry.categorize(account: 'Blahh')

      assert journal_entry.changed?
    end

    def test_unprocessed_true
      assert JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Account1', amount: Money.new(1)),
          BookEntry.new(account: 'income:unknown', amount: Money.new(-1))
        ]
      ).unprocessed?
    end

    def test_unprocessed_false
      refute JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Account1', amount: Money.new(1)),
          BookEntry.new(account: 'Account2', amount: Money.new(-1))
        ]
      ).unprocessed?
    end

    def test_split_with_jacinthe
      actual = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Assets:Checking:TD', amount: Money.new(1)),
          BookEntry.new(account: 'income:unknown', amount: Money.new(-1))
        ]
      )
      expected = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Assets:Checking:TD', amount: Money.new(1)),
          BookEntry.new(account: 'Assets:Reimbursements:Splitwise:Jacinthe', amount: Money.new(-0.5)),
          BookEntry.new(account: 'Income:Other', amount: Money.new(-0.5))
        ]
      )
      actual.split_with_jacinthe(other_account: 'Income:Other')
      assert_equal expected, actual
    end

    def test_split_with_jacinthe_raises_if_theres_nothing_to_split
      actual = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Assets:Checking:TD', amount: Money.new(1)),
          BookEntry.new(account: 'Expenses', amount: Money.new(-1))
        ]
      )
      assert_raises do
        actual.split_with_jacinthe(other_account: 'Income:Other')
      end
    end

    def test_equals_true
      je1 = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Assets:Checking:TD', amount: Money.new(1)),
          BookEntry.new(account: 'Expenses', amount: Money.new(-1))
        ]
      )
      je2 = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Assets:Checking:TD', amount: Money.new(1)),
          BookEntry.new(account: 'Expenses', amount: Money.new(-1))
        ]
      )
      assert_equal je1, je2
    end

    def test_equals_false_because_of_description
      je1 = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Assets:Checking:TD', amount: Money.new(1)),
          BookEntry.new(account: 'Expenses', amount: Money.new(-1))
        ]
      )
      je2 = JournalEntry.new(
        description: 'not equal',
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Assets:Checking:TD', amount: Money.new(1)),
          BookEntry.new(account: 'Expenses', amount: Money.new(-1))
        ]
      )
      refute_equal je1, je2
    end

    def test_equals_false_because_of_date
      je1 = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Assets:Checking:TD', amount: Money.new(1)),
          BookEntry.new(account: 'Expenses', amount: Money.new(-1))
        ]
      )
      je2 = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE + 1,
        book_entries: [
          BookEntry.new(account: 'Assets:Checking:TD', amount: Money.new(1)),
          BookEntry.new(account: 'Expenses', amount: Money.new(-1))
        ]
      )
      refute_equal je1, je2
    end

    def test_equals_false_because_of_journal_entries
      je1 = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Assets:Checking:TD', amount: Money.new(1)),
          BookEntry.new(account: 'Expenses', amount: Money.new(-1))
        ]
      )
      je2 = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Assets:Checking:TD', amount: Money.new(1)),
          BookEntry.new(account: 'Expenses', amount: Money.new(-2))
        ]
      )
      refute_equal je1, je2
    end

    def test_sync_with_external_doesnt_do_anything_if_nothing_has_changed
      actual = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Assets:Checking:TD', amount: Money.new(1)),
          BookEntry.new(account: 'Assets:Reimbursements:Splitwise:Jacinthe', amount: Money.new(-1))
        ]
      )
      Beeminder::Client.any_instance.expects(:submit_expense).never
      Splitwise::Client.any_instance.expects(:create_expense).never

      actual.sync_with_external
    end

    def test_sync_with_external_calls_both_splitwise_and_beeminder_clients
      actual = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Assets:Checking:TD', amount: Money.new(1)),
          BookEntry.new(account: 'income:unknown', amount: Money.new(-1))
        ]
      )
      expense = Splitwise::Expense.new(
        cost: Money.new(1),
        date: DATE,
        description: DESCRIPTION,
        expense_shares: [
          Splitwise::ExpenseShare.new(
            user_id: JournalEntry::JACINTHE_SPLITWISE_ID,
            paid: Money.new(0.5),
            owes: Money.new(0)
          ),
          Splitwise::ExpenseShare.new(
            user_id: JournalEntry::SHARDUL_SPLITWISE_ID,
            paid: Money.new(0.5),
            owes: Money.new(1.00)
          )
        ]
      )
      Splitwise::Client.any_instance.expects(:create_expense).with(expense)
      actual.split_with_jacinthe(other_account: 'Expenses:Discretionary')

      actual.sync_with_external
    end

    def test_sync_with_external_calls_only_splitwise_if_other_account_is_not_discretionary
      actual = JournalEntry.new(
        description: DESCRIPTION,
        date: DATE,
        book_entries: [
          BookEntry.new(account: 'Assets:Checking:TD', amount: Money.new(1)),
          BookEntry.new(account: 'income:unknown', amount: Money.new(-1))
        ]
      )
      expense = Splitwise::Expense.new(
        cost: Money.new(1),
        date: DATE,
        description: DESCRIPTION,
        expense_shares: [
          Splitwise::ExpenseShare.new(
            user_id: JournalEntry::JACINTHE_SPLITWISE_ID,
            paid: Money.new(0.5),
            owes: Money.new(0)
          ),
          Splitwise::ExpenseShare.new(
            user_id: JournalEntry::SHARDUL_SPLITWISE_ID,
            paid: Money.new(0.5),
            owes: Money.new(1.00)
          )
        ]
      )
      Beeminder::Client.any_instance.expects(:submit_expense).never
      Splitwise::Client.any_instance.expects(:create_expense).with(expense)
      actual.split_with_jacinthe(other_account: 'Expenses:Recurring')

      actual.sync_with_external
    end
  end
end
