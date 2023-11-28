# typed: strict
# frozen_string_literal: true

require 'money'
require 'sorbet-runtime'
require 'ledger/journal'

module Ledger

  class Parser
    extend(T::Sig)

    class ParseError < StandardError; end
    class UnbalancedBookEntry < T::Struct
      extend(T::Sig)

      const :account, String
      const :amount, T.nilable(Money)
      const :balance_assertion, T.nilable(Money)
      const :id, T.nilable(String)

      sig { returns(BookEntry) }
      def to_balanced_book_entry
        BookEntry.new(
          account: account,
          amount: T.must(amount),
          balance_assertion: balance_assertion,
          id: id
        )
      end
    end

    COMMENT = /\s*#/
    DATE = /(\d{4}-\d{2}-\d{2})/
    PAYEE = /.*$/
    ACCOUNT = /[a-z0-9A-Z:]+/
    AMOUNT = /-{0,1}\d{1,}\.\d{2}/
    BALANCE_ASSERTION = /\s*=\s*/

    ONE_OR_MORE_NEWLINES = /\n+/
    ONE_NEWLINE = /\n/
    TWO_OR_MORE_SPACES = / {2,}|\t/
    ONE_OR_MORE_SPACES = /\s+/

    sig {params(string: String).void}
    def initialize(string)
      @scanner = T.let(StringScanner.new(string), StringScanner)
    end

    sig {params(dirname: String).returns(Journal)}
    def self.parse_dir(dirname)
      raise unless File.directory?(dirname)

      subjournals = []
      Dir.each_child(dirname) do |filename|
        next unless filename.match(/\d{4}-\d{2}.journal/)

        subjournals << Parser.new(IO.read(File.join(dirname, filename))).parse
      end
      raise if subjournals.empty?

      return subjournals.reduce(&:+)
    end

    sig { returns(Journal) }
    def parse
      journal_entries = []
      until @scanner.eos?
        case
        when @scanner.check(COMMENT)
          @scanner.skip_until(/$/)
        when @scanner.check(DATE)
          journal_entries << parse_journal_entry
        when @scanner.check(ONE_OR_MORE_NEWLINES)
          @scanner.skip_until(ONE_OR_MORE_NEWLINES)
        else
          raise ParseError, "Parsing failed around #{current_line_number}."
        end
      end
      Journal.new(journal_entries)
    end

    private

    sig { returns(JournalEntry) }
    def parse_journal_entry
      date = Date.strptime(@scanner.scan(DATE), '%Y-%m-%d')
      @scanner.skip(ONE_OR_MORE_SPACES)
      description = @scanner.scan(PAYEE)
      @scanner.skip(ONE_NEWLINE)

      book_entries = []
      until @scanner.check(DATE) || @scanner.eos?
        book_entries << parse_book_entry
      end

      JournalEntry.new(date: date, description: T.must(description), book_entries: balance(book_entries))
    end

    sig { returns(UnbalancedBookEntry) }
    def parse_book_entry
      unless @scanner.skip(ONE_OR_MORE_SPACES)
        raise ParseError.new("Book entry must start with one or more spaces on line #{current_line_number}.")
      end
      unless account = @scanner.scan(ACCOUNT)
        raise ParseError.new("Unable to parse account on line #{current_line_number}.")
      end

      if @scanner.check(TWO_OR_MORE_SPACES)
        @scanner.skip(TWO_OR_MORE_SPACES)
        if amount = @scanner.scan(AMOUNT)
          amount = Money.new(amount)
        end
        balance_assertion = nil
        if @scanner.check(BALANCE_ASSERTION)
          @scanner.skip_until(BALANCE_ASSERTION)
          balance_assertion = Money.new(@scanner.scan(AMOUNT))
        end
        id = nil
        if @scanner.check(/[ \t]*;[ \t]*tid:/)
          @scanner.skip(/[ \t]*;[ \t]*tid:/)
          @scanner.scan(/([^\s]+)[ \t]*$/)
          id = @scanner.captures.first
        end
        @scanner.skip(ONE_OR_MORE_NEWLINES)
      elsif @scanner.check(ONE_OR_MORE_NEWLINES)
        @scanner.skip(ONE_OR_MORE_NEWLINES)
      elsif @scanner.eos?
      else
        raise "Unable to parse book entry on line #{current_line_number}."
      end
      UnbalancedBookEntry.new(account: account, amount: amount, balance_assertion: balance_assertion, id: id)
    end

    sig { params(book_entries: T::Array[UnbalancedBookEntry]).returns(T::Array[Ledger::BookEntry])}
    def balance(book_entries)
      if book_entries.length == book_entries.map(&:amount).compact.length
        return book_entries.map(&:to_balanced_book_entry)
      end

      if book_entries.length - book_entries.map(&:amount).compact.length > 1
        raise ParseError.new("Too many unbalanced book entries around line #{current_line_number}.")
      end

      unbalanced, balanced = book_entries.partition { |be| be.amount.nil? }
      unbalanced = T.must(unbalanced.first)
      balanced.map(&:to_balanced_book_entry).push(BookEntry.new(
        account: unbalanced.account,
        amount: -T.must(balanced.map(&:amount).sum),
        balance_assertion: unbalanced.balance_assertion,
        id: unbalanced.id
      ))
    end

    sig { returns(Integer) }
    def current_line_number
      @scanner.string[0..@scanner.pos].count("\n") + 1
    end
  end
end
