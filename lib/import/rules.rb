# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require 'sorbet-struct-comparable'

module Import
  module Rules
    extend(T::Sig)

    module ImportableTransaction
      extend(T::Helpers)
      extend(T::Sig)

      sealed!
      interface!

      sig {abstract.params(journal_entry: Ledger::JournalEntry).void}
      def initialize(journal_entry); end

      sig {abstract.returns(T::Boolean)}
      def valid?; end

      sig {abstract.returns(Ledger::JournalEntry)}
      def classify; end

      class Telus
        extend(T::Sig)
        include(ImportableTransaction)

        sig {override.params(journal_entry: Ledger::JournalEntry).void}
        def initialize(journal_entry)
          @journal_entry = journal_entry
        end

        sig {override.returns(T::Boolean)}
        def valid?
          return false if !@journal_entry.description.match?(/TELUS MOBILITY PREAUTH/)
          return false if !@journal_entry.unprocessed?
          true
        end

        sig {override.returns(Ledger::JournalEntry)}
        def classify
          gl_entry = T.must(@journal_entry.book_entries.find { _1.real_account_book? })
          rishav_entry = Ledger::BookEntry.new(
            amount: Money.new(75.00),
            account: 'Assets:Reimbursements:Rishav'
          )
          remaining = Ledger::BookEntry.new(
            amount: -gl_entry.amount - rishav_entry.amount,
            account: 'Expenses:Recurring'
          )
          Ledger::JournalEntry.new(
            book_entries: [gl_entry, rishav_entry, remaining],
            description: @journal_entry.description,
            date: @journal_entry.date
          )
        end
      end
    end

    sig {params(journal_entry: Ledger::JournalEntry).returns(T::Array[ImportableTransaction])}
    def self.classify(journal_entry)
      ImportableTransaction.sealed_subclasses.map do |subclass|
        importable_instance = subclass.new(journal_entry)
        next if !importable_instance.valid?
        importable_instance
      end.compact
    end
  end
end

