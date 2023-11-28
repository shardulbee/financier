# typed: false
# frozen_string_literal: true

require 'date'
require 'money'

require 'beeminder/client'
require 'ledger/book_entry'
require 'splitwise/client'

module Ledger
  class JournalEntry
    class MoneySplit < T::Struct
      const :other_amount, Money
      const :own_amount, Money
    end

    JACINTHE_SPLITWISE_ID = 9239057
    SHARDUL_SPLITWISE_ID = 1570407

    extend(T::Sig)

    sig { returns(T::Array[BookEntry]) }
    attr_reader :book_entries

    sig { returns(Date) }
    attr_reader :date

    sig { returns(String) }
    attr_reader :description

    sig { params(date: Date, description: String, book_entries: T::Array[BookEntry]).void }
    def initialize(date:, description:, book_entries:)
      @date = date
      @description = description
      @book_entries = book_entries
      @changed = T.let(false, T::Boolean)
    end

    sig { params(transaction: Import::Transaction).returns(T::Boolean) }
    def associate(transaction)
      matching_book_entry = book_entries.find { |book_entry| book_entry.looks_like?(transaction) }
      if date == transaction.date && !!matching_book_entry
        matching_book_entry.update(id: transaction.full_id)
        return true
      end
      false
    end

    sig { returns(T::Array[String]) }
    def book_entry_ids
      book_entries.map(&:id).compact
    end

    sig { returns(T::Array[String]) }
    def accounts
      book_entries.map(&:account)
    end

    sig { returns(T::Boolean) }
    def unprocessed?
      @book_entries.any? { |book_entry| book_entry.default_book? }
    end

    sig { returns(T::Boolean) }
    def changed?
      @changed
    end

    sig {returns(T::Boolean)}
    def splittable?
      # it has to have been processed
      return false if !changed?

      # it has to come from a real account
      return false if untouched_book_entry.nil?

      # one of the book entries has to go to splitwise
      return false if book_entries.none? do |book_entry|
        book_entry.account == 'Assets:Reimbursements:Splitwise:Jacinthe' &&
          book_entry.id.nil?
      end

      # it is a payment
      return false if description.include?('E-TRANSFER')

      true
    end

    sig { void }
    def sync_with_external
      return unless splittable?

      jacinthe_book_entry = T.must(
        @book_entries.find { |book_entry| book_entry.account == 'Assets:Reimbursements:Splitwise:Jacinthe' }
      )

      expense = if untouched_book_entry.amount > 0
        Splitwise::Expense.new(
          cost: untouched_book_entry.amount.abs,
          description: description,
          date: date,
          expense_shares: [
            Splitwise::ExpenseShare.new(
              user_id: JACINTHE_SPLITWISE_ID,
              paid: jacinthe_book_entry.amount.abs,
              owes: Money.new(0)
            ),
            Splitwise::ExpenseShare.new(
              user_id: SHARDUL_SPLITWISE_ID,
              paid: untouched_book_entry.amount.abs - jacinthe_book_entry.amount.abs,
              owes: untouched_book_entry.amount.abs
            )
          ]
        )
      else
        Splitwise::Expense.new(
          cost: untouched_book_entry.amount.abs,
          description: description,
          date: date,
          expense_shares: [
            Splitwise::ExpenseShare.new(
              user_id: JACINTHE_SPLITWISE_ID,
              paid: Money.new(0),
              owes: jacinthe_book_entry.amount
            ),
            Splitwise::ExpenseShare.new(
              user_id: SHARDUL_SPLITWISE_ID,
              paid: -untouched_book_entry.amount,
              owes: -untouched_book_entry.amount - jacinthe_book_entry.amount
            )
          ]
        )
      end
      # TODO: set the ID of the journal entry to the ID of the splitwise thing right away
      Splitwise::Client
        .new(auth_token: T.must(ENV['SPLITWISE_API_KEY']))
        .create_expense(expense)
    end

    sig { params(other_account: String).void }
    def split_with_jacinthe(other_account:)
      raise unless unprocessed?

      jacinthe_entry = BookEntry.new(
        account: 'Assets:Reimbursements:Splitwise:Jacinthe',
        amount: split_amount.other_amount,
        balance_assertion: nil
      )
      categorized_entry = book_entry_to_categorize.update(
        account: other_account,
        amount: split_amount.own_amount,
        balance_assertion: nil
      )

      @book_entries = [jacinthe_entry, categorized_entry, untouched_book_entry]
      @changed = true
    end

    sig { params(account: String).void }
    def categorize(account:)
      book_entry_to_categorize.update(account: account)
      @changed = true
    end

    sig { returns(String) }
    def to_s
      lines = ["#{@date.strftime('%Y-%m-%d')} #{@description}"]
      lines.concat(@book_entries.map(&:to_s)).join("\n")
    end

    sig { params(other: JournalEntry).returns(T::Boolean) }
    def ==(other)
      date == other.date &&
        description == other.description &&
        book_entries.sort_by(&:account) == other.book_entries.sort_by(&:account)
    end

    private

    sig { returns(MoneySplit) }
    def split_amount
      split = book_entry_to_categorize.amount.split(2)
      MoneySplit.new(other_amount: split[0], own_amount: split[1])
    end

    sig { returns(BookEntry) }
    def book_entry_to_categorize
      T.must(@book_entries.find(&:default_book?))
    end

    sig { returns(T.nilable(BookEntry)) }
    def untouched_book_entry
      @book_entries.find(&:real_account_book?)
    end
  end
end
