# typed: true
# frozen_string_literal: true

require_relative 'test_helper'
require 'ledger/book_entry'

module Ledger
  class BookEntryTest < Minitest::Test
    def test_equals_fails_when_amounts_not_equal
      first_book_entry = BookEntry.new(account: 'Account', amount: Money.new(123))
      second_book_entry = BookEntry.new(account: 'Account', amount: Money.new(123.1))

      refute first_book_entry == second_book_entry
    end

    def test_equals_fails_when_accounts_not_equal
      first_book_entry = BookEntry.new(account: 'Account1', amount: Money.new(123))
      second_book_entry = BookEntry.new(account: 'Account2', amount: Money.new(123))

      refute first_book_entry == second_book_entry
    end

    def test_equals_fails_when_balance_assertions_are_not_equal
      first_book_entry = BookEntry.new(account: 'Account', amount: Money.new(1), balance_assertion: Money.new(123))
      second_book_entry = BookEntry.new(account: 'Account', amount: Money.new(1), balance_assertion: Money.new(234))

      refute first_book_entry == second_book_entry
    end

    def test_equals_fails_when_only_one_assertion_is_nil
      first_book_entry = BookEntry.new(account: 'Account', amount: Money.new(1), balance_assertion: nil)
      second_book_entry = BookEntry.new(account: 'Account', amount: Money.new(1), balance_assertion: Money.new(234))

      refute first_book_entry == second_book_entry
    end

    def test_equals_succeeds_when_both_assertions_are_nil
      first_book_entry = BookEntry.new(account: 'Account', amount: Money.new(1), balance_assertion: nil)
      second_book_entry = BookEntry.new(account: 'Account', amount: Money.new(1), balance_assertion: nil)

      assert first_book_entry == second_book_entry
    end

    def test_equals_fails_when_ids_are_not_equal
      first_book_entry = BookEntry.new(account: 'Account', amount: Money.new(1), balance_assertion: nil, id: '123')
      second_book_entry = BookEntry.new(account: 'Account', amount: Money.new(1), balance_assertion: nil, id: '234')

      refute first_book_entry == second_book_entry
    end

    def test_equals_fails_when_only_one_id_is_nil
      first_book_entry = BookEntry.new(account: 'Account', amount: Money.new(1), balance_assertion: nil, id: nil)
      second_book_entry = BookEntry.new(account: 'Account', amount: Money.new(1), balance_assertion: nil, id: '234')

      refute first_book_entry == second_book_entry
    end

    def test_equals_succeeds_when_both_ids_are_nil
      first_book_entry = BookEntry.new(account: 'Account', amount: Money.new(1), balance_assertion: nil, id: nil)
      second_book_entry = BookEntry.new(account: 'Account', amount: Money.new(1), balance_assertion: nil, id: nil)

      assert first_book_entry == second_book_entry
    end

    def test_equals_succeeds_when_no_values_are_nil_and_all_are_equal
      first_book_entry = BookEntry.new(
        account: 'Account',
        amount: Money.new(1),
        balance_assertion: Money.new(1),
        id: '123'
      )
      second_book_entry = BookEntry.new(
        account: 'Account',
        amount: Money.new(1),
        balance_assertion: Money.new(1),
        id: '123'
      )

      assert first_book_entry == second_book_entry
    end

    def test_default_book_is_false
      refute BookEntry.new(account: 'NotDefaultBook', amount: Money.new(1)).default_book?
    end

    def test_default_book_is_true
      assert BookEntry.new(account: 'expenses:unknown', amount: Money.new(1)).default_book?
      assert BookEntry.new(account: 'income:unknown', amount: Money.new(1)).default_book?
    end

    def test_real_account_book_is_false
      refute BookEntry.new(account: 'NotRealAccountBook', amount: Money.new(1)).real_account_book?
    end

    def test_real_account_book_is_true
      Import::Account.real_accounts.each do |real_account|
        book_entry = BookEntry.new(
          account: real_account.ledger_account,
          amount: Money.new(1)
        )
        assert(book_entry.real_account_book?, "#{real_account} was not considered real")
      end
    end

    def test_to_s_when_everything_except_account_and_amount_is_nil
      expected = <<-journal.chomp
    Checking  123.23
      journal
      assert_equal expected, BookEntry.new(account: 'Checking', amount: Money.new(123.23)).to_s
    end

    def test_to_s_when_only_id_is_nil
      expected = <<-journal.chomp
    Checking  123.23 = 234.23
      journal
      assert_equal expected, BookEntry.new(account: 'Checking', amount: Money.new(123.23), balance_assertion: Money.new(234.23)).to_s
    end

    def test_to_s_when_nothing_is_nil
      expected = <<-journal.chomp
    Checking  123.23 = 234.23 ; tid:abc123
      journal
      assert_equal expected, BookEntry.new(
        account: 'Checking',
        amount: Money.new(123.23),
        balance_assertion: Money.new(234.23),
        id: 'abc123'
      ).to_s
    end

    def test_to_s_when_only_assertion_is_nil
      expected = <<-journal.chomp
    Checking  123.23 ; tid:abc123
      journal
      assert_equal expected, BookEntry.new(
        account: 'Checking',
        amount: Money.new(123.23),
        balance_assertion: nil,
        id: 'abc123'
      ).to_s
    end

    def test_update_account
      book_entry = BookEntry.new(account: 'Checking', amount: Money.new(1))
      book_entry.update(account: 'Credit')

      assert_equal 'Credit', book_entry.account
      assert_equal Money.new(1), book_entry.amount
      assert_nil book_entry.balance_assertion
      assert_nil book_entry.id
    end

    def test_update_amount
      book_entry = BookEntry.new(account: 'Checking', amount: Money.new(1))
      book_entry.update(amount: Money.new(123.23))

      assert_equal Money.new(123.23), book_entry.amount
      assert_equal 'Checking', book_entry.account
      assert_nil book_entry.balance_assertion
      assert_nil book_entry.id
    end

    def test_update_assertion
      book_entry = BookEntry.new(account: 'Checking', amount: Money.new(1))
      book_entry.update(balance_assertion: Money.new(123.23))

      assert_equal Money.new(123.23), book_entry.balance_assertion
      assert_equal 'Checking', book_entry.account
      assert_equal Money.new(1), book_entry.amount
      assert_nil book_entry.id
    end

    def test_update_id
      book_entry = BookEntry.new(account: 'Checking', amount: Money.new(1))
      book_entry.update(id: 'abc')

      assert_equal 'abc', book_entry.id
      assert_equal 'Checking', book_entry.account
      assert_equal Money.new(1), book_entry.amount
      assert_nil book_entry.balance_assertion
    end

    def test_update_multiple
      book_entry = BookEntry.new(account: 'Checking', amount: Money.new(1))
      book_entry.update(account: 'Credit', amount: Money.new(123.23), balance_assertion: Money.new(1), id: 'abc')

      assert_equal 'abc', book_entry.id
      assert_equal 'Credit', book_entry.account
      assert_equal Money.new(123.23), book_entry.amount
      assert_equal Money.new(1), book_entry.balance_assertion
    end

    def test_looks_like_transaction
      transaction = Import::Transaction.new(
        amount: Money.new(1),
        transaction_id: 'abc123',
        account: Import::Account::TDChecking,
        payee: 'not important',
        date: Date.today,
        kind: Import::Transaction::Kind::Credit
      )
      book_entry = BookEntry.new(
        account: Import::Account::TDChecking.ledger_account,
        amount: Money.new(1)
      )

      assert book_entry.looks_like?(transaction)
    end

    def test_looks_like_transaction_false_if_amount_differs
      transaction = Import::Transaction.new(
        amount: Money.new(12),
        transaction_id: 'abc123',
        account: Import::Account::TDChecking,
        payee: 'not important',
        date: Date.today,
        kind: Import::Transaction::Kind::Credit
      )
      book_entry = BookEntry.new(
        account: Import::Account::TDChecking.ledger_account,
        amount: Money.new(1)
      )

      refute book_entry.looks_like?(transaction)
    end

    def test_looks_like_transaction_false_if_account_differs
      transaction = Import::Transaction.new(
        amount: Money.new(1),
        transaction_id: 'abc123',
        account: Import::Account::TDCreditNew,
        payee: 'not important',
        date: Date.today,
        kind: Import::Transaction::Kind::Credit
      )
      book_entry = BookEntry.new(
        account: Import::Account::TDChecking.ledger_account,
        amount: Money.new(1)
      )

      refute book_entry.looks_like?(transaction)
    end

    def test_looks_like_transaction_false_if_id_is_non_nil
      transaction = Import::Transaction.new(
        amount: Money.new(1),
        transaction_id: 'abc123',
        account: Import::Account::TDCreditNew,
        payee: 'not important',
        date: Date.today,
        kind: Import::Transaction::Kind::Credit
      )
      book_entry = BookEntry.new(
        account: Import::Account::TDChecking.ledger_account,
        amount: Money.new(1),
        id: 'abc'
      )

      refute book_entry.looks_like?(transaction)
    end

  end
end
