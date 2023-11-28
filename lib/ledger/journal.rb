# typed: strict
# frozen_string_literal: true

require 'date'
require 'money'
require 'tempfile'
require 'ledger/journal_entry'
require 'ledger/book_entry'

module Ledger
  class Journal
    extend(T::Sig)

    sig { returns(T::Array[JournalEntry]) }
    attr_reader :journal_entries

    sig { params(journal_entries: T::Array[JournalEntry]).void }
    def initialize(journal_entries)
      @journal_entries = journal_entries
    end

    sig {params(other: Journal).returns(Journal)}
    def +(other)
      Journal.new(journal_entries + other.journal_entries)
    end

    sig {params(balance: Import::Balance).returns(T::Boolean)}
    def assert_balance(balance)
      assertion = Ledger::JournalEntry.new(
        book_entries: [
          Ledger::BookEntry.new(
            account: balance.account.ledger_account,
            amount: Money.new(0),
            balance_assertion: balance.amount,
            id: "#{balance.account.serialize}.#{balance.as_of.strftime('%Y%m%d')}"
          )
        ],
        description: "BALANCE ASSERTION",
        date: balance.as_of
      )
      Journal.new(@journal_entries.dup.push(assertion)).valid?
    end

    sig {returns(T::Boolean)}
    def valid?
      Tempfile.open('test_journal.hledger') do |f|
        f.write(to_s)
        f.rewind

        return T.must(Kernel.system("hledger -f #{f.path.to_s} check"))
      end
    end

    sig {params(balance: Import::Balance).void}
    def import_balance(balance)
      assertion = Ledger::JournalEntry.new(
        book_entries: [
          Ledger::BookEntry.new(
            account: balance.account.ledger_account,
            amount: Money.new(0),
            balance_assertion: balance.amount,
            id: balance.ledger_id
          )
        ],
        description: "BALANCE ASSERTION",
        date: balance.as_of
      )
      return if existing_transaction_ids.include?(balance.ledger_id)
      @journal_entries.push(assertion)
    end

    sig { params(transaction: Import::Transaction).returns(T.nilable(JournalEntry)) }
    def import_transaction(transaction)
      return if existing_transaction_ids.include?(transaction.full_id)
      return if associate_to_existing_journal_entry(transaction)

      book_entries = [
        Ledger::BookEntry.new(
          account: transaction.source_ledger_account,
          amount: transaction.amount,
          id: transaction.full_id
        ),
        Ledger::BookEntry.new(
          account: T.must(transaction.destination_ledger_account),
          amount: -transaction.amount
        )
      ]

      journal_entries.push(Ledger::JournalEntry.new(
        date: transaction.date,
        description: transaction.payee,
        book_entries: book_entries
      ))
      journal_entries.last
    end

    sig { returns(Integer) }
    def length
      journal_entries.length
    end

    sig { returns(String) }
    def to_s
      (journal_entries.map(&:to_s)).join("\n\n") + "\n"
    end

    sig { returns(T::Boolean) }
    def empty?
      journal_entries.empty?
    end

    sig { params(dir: String).returns(T::Boolean) }
    def write(dir)
      main_path = File.join(dir, 'main.journal')
      File.delete(main_path)
      FileUtils.touch(main_path)

      journal_entries
        .group_by {_1.date.strftime('%Y-%m')}
        .map { {yyyymm: _1, sub_journal: Journal.new(_2)} }
        .sort_by! { _1[:yyyymm] }
        .each do |sub_journal|
          File.write(
            File.join(dir, "#{sub_journal[:yyyymm]}.journal"),
            sub_journal[:sub_journal].to_s
          )
          File.write(
            File.join(dir, 'main.journal'),
            "include #{sub_journal[:yyyymm]}.journal\n",
            File.size(File.join(dir, 'main.journal')),
            mode: 'a'
          )
        end
      true
    end

    sig { returns(T::Array[String]) }
    def accounts
      journal_entries.flat_map(&:accounts).uniq
    end

    private

    sig { returns(T::Array[String]) }
    def existing_transaction_ids
      journal_entries.flat_map(&:book_entry_ids)
    end

    sig { params(transaction: Import::Transaction).returns(T::Boolean) }
    def associate_to_existing_journal_entry(transaction)
      journal_entries.reverse.each do |journal_entry|
        if journal_entry.associate(transaction)
          return true
        end
      end
      false
    end
  end
end
