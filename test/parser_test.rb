# typed: true
# frozen_string_literal: true

require_relative 'test_helper'

require 'ledger/parser'

module Ledger

	class ParserTest < Minitest::Test
		def test_no_journal_entries
			assert_predicate Ledger::Parser.new('').parse, :empty?
		end

		def test_no_journal_entries_with_comment 
			assert_predicate Ledger::Parser.new('# this is a comment').parse, :empty?
		end

		def test_trailing_newlines
			assert_predicate Ledger::Parser.new('# this is a comment\n\n\n\n').parse, :empty?
		end

		def test_one_journal_entry
			entry = <<-je
2020-01-01 Uber Eats
	Assets:Checking  123.23
	Expenses:Food  -123.23
			je
			assert_equal 1, Ledger::Parser.new(entry).parse.length
		end	

		def test_trailing_and_leading_newlines
			entry = <<-je


2020-01-01 Uber Eats
	Assets:Checking  123.23
	Expenses:Food  -123.23





			je
			assert_equal 1, Ledger::Parser.new(entry).parse.length
		end

		def test_repeated_whitespace 
			entry = <<-je
2020-01-01       Uber Eats            
	Assets:Checking             123.23            =                  234.23
	Expenses:Food                 -123.23
			je
			assert_equal 1, Ledger::Parser.new(entry).parse.length
		end

		def test_one_journal_entry_with_comment
			entry = <<-je
# vim:filetype=ledger
2020-01-01 Uber Eats
	Assets:Checking  123.23
	Expenses:Food  -123.23
			je
			assert_equal 1, Ledger::Parser.new(entry).parse.length
		end	

		def test_two_journal_entries_no_blank_line
			entry = <<-je
2020-01-01 Uber Eats
	Assets:Checking  123.23
	Expenses:Food  -123.23
2020-01-01 Uber Eats 2
	Assets:Checking  234.23
	Expenses:Food  234.23
			je
			assert_equal 2, Ledger::Parser.new(entry).parse.length
		end	

		def test_two_journal_entries_with_blank_line
			entry = <<-je
2020-01-01 Uber Eats
	Assets:Checking  123.23
	Expenses:Food  -123.23

2020-01-01 Uber Eats 2
	Assets:Checking  234.23
	Expenses:Food  234.23
			je
			assert_equal 2, Ledger::Parser.new(entry).parse.length
		end	

		def test_book_entry_with_balance_assertion
			entry = <<-je
2020-01-01 Uber Eats
	Assets:Checking  123.23 = 123.23
	Expenses:Food  -123.23
			je

			actual_journal = Ledger::Parser.new(entry).parse
			assert_equal 1, actual_journal.length

			actual_journal_entry = actual_journal.journal_entries.first
			expected_journal_entry = Ledger::JournalEntry.new(
				date: Date.new(2020, 1, 1),
				description: 'Uber Eats',
				book_entries: [
					Ledger::BookEntry.new(account: 'Assets:Checking', amount: Money.new(123.23), balance_assertion: Money.new(123.23)),
					Ledger::BookEntry.new(account: 'Expenses:Food', amount: Money.new(-123.23), balance_assertion: nil)
				]	
			)
			assert_equal expected_journal_entry, actual_journal_entry
		end	

		def test_book_entry_with_multiple_balance_assertions
			entry = <<-je
2020-01-01 Uber Eats
	Assets:Checking  123.23 = 123.23
	Expenses:Food  -123.23 = 0.00
			je

			actual_journal = Ledger::Parser.new(entry).parse
			assert_equal 1, actual_journal.length

			actual_journal_entry = actual_journal.journal_entries.first
			expected_journal_entry = Ledger::JournalEntry.new(
				date: Date.new(2020, 1, 1),
				description: 'Uber Eats',
				book_entries: [
					Ledger::BookEntry.new(account: 'Assets:Checking', amount: Money.new(123.23), balance_assertion: Money.new(123.23)),
					Ledger::BookEntry.new(account: 'Expenses:Food', amount: Money.new(-123.23), balance_assertion: Money.new(0))
				]	
			)
			assert_equal expected_journal_entry, actual_journal_entry
		end	

		def test_book_entry_with_more_than_2_book_entries
			entry = <<-je
2020-01-01 Uber Eats
	Assets:Checking  123.23 = 123.23
	Expenses:Food  -123.23 = 0.00
	Expenses:Food  -123.23 = 0.00
			je

			actual_journal = Ledger::Parser.new(entry).parse
			assert_equal 1, actual_journal.length

			actual_journal_entry = actual_journal.journal_entries.first
			expected_journal_entry = Ledger::JournalEntry.new(
				date: Date.new(2020, 1, 1),
				description: 'Uber Eats',
				book_entries: [
					Ledger::BookEntry.new(account: 'Assets:Checking', amount: Money.new(123.23), balance_assertion: Money.new(123.23)),
					Ledger::BookEntry.new(account: 'Expenses:Food', amount: Money.new(-123.23), balance_assertion: Money.new(0)),
					Ledger::BookEntry.new(account: 'Expenses:Food', amount: Money.new(-123.23), balance_assertion: Money.new(0))
				]	
			)
			assert_equal expected_journal_entry, actual_journal_entry
		end	

		def test_book_entry_with_no_amount
			entry = <<-je
2020-01-01 Uber Eats
	Assets:Checking  123.23 = 123.23
	Expenses:Food
			je

			actual_journal = Ledger::Parser.new(entry).parse
			assert_equal 1, actual_journal.length

			actual_journal_entry = actual_journal.journal_entries.first
			expected_journal_entry = Ledger::JournalEntry.new(
				date: Date.new(2020, 1, 1),
				description: 'Uber Eats',
				book_entries: [
					Ledger::BookEntry.new(account: 'Assets:Checking', amount: Money.new(123.23), balance_assertion: Money.new(123.23)),
					Ledger::BookEntry.new(account: 'Expenses:Food', amount: Money.new(-123.23), balance_assertion: nil),
				]	
			)
			assert_equal expected_journal_entry, actual_journal_entry
		end	

		def test_book_entry_with_no_amount_but_with_balance_assertion
			entry = <<-je
2020-01-01 Uber Eats
	Assets:Checking  123.23 = 123.23
	Expenses:Food  = 5000.00
			je

			actual_journal = Ledger::Parser.new(entry).parse
			assert_equal 1, actual_journal.length

			actual_journal_entry = actual_journal.journal_entries.first
			expected_journal_entry = Ledger::JournalEntry.new(
				date: Date.new(2020, 1, 1),
				description: 'Uber Eats',
				book_entries: [
					Ledger::BookEntry.new(account: 'Assets:Checking', amount: Money.new(123.23), balance_assertion: Money.new(123.23)),
					Ledger::BookEntry.new(account: 'Expenses:Food', amount: Money.new(-123.23), balance_assertion: Money.new(5000)),
				]	
			)
			assert_equal expected_journal_entry, actual_journal_entry
		end	

		def test_raises_if_too_many_unbalanced_book_entries
			entry = <<-je
2020-01-01 Uber Eats
	Assets:Checking  123.23 = 123.23
	Expenses:Food
	Expenses:Peanut
			je

			e = assert_raises do 
				Ledger::Parser.new(entry).parse
			end

			assert_match(/Too many unbalanced book entries/, e.message)
		end	

		def test_raises_unless_at_least_one_space_before_account
			entry = <<-je
2020-01-01 Uber Eats
Assets:Checking  123.23 = 123.23
	Expenses:Food
			je

			e = assert_raises do 
				Ledger::Parser.new(entry).parse
			end

			assert_match(/Book entry must start with one or more spaces/, e.message)
		end	

		def test_parses_transaction_id
			entry = <<-je
2020-01-01 Uber Eats
	Assets:Checking  123.23 = 123.23 ; tid:64001023.skljsdkfjsdlkjf
	Expenses:Food  = 5000.00
			je

			actual_journal = Ledger::Parser.new(entry).parse
			assert_equal 1, actual_journal.length

			actual_journal_entry = actual_journal.journal_entries.first
			expected_journal_entry = Ledger::JournalEntry.new(
				date: Date.new(2020, 1, 1),
				description: 'Uber Eats',
				book_entries: [
					Ledger::BookEntry.new(
						account: 'Assets:Checking', 
						amount: Money.new(123.23), 
						balance_assertion: Money.new(123.23),
						id: '64001023.skljsdkfjsdlkjf'
					),
					Ledger::BookEntry.new(account: 'Expenses:Food', amount: Money.new(-123.23), balance_assertion: Money.new(5000)),
				]	
			)
			assert_equal expected_journal_entry, actual_journal_entry
		end	

		def test_parses_transaction_id_with_whitespace_after
			entry = <<-je
2020-01-01 Uber Eats
	Assets:Checking  123.23 = 123.23 ; tid:64001023.skljsdkfjsdlkjf      
	Expenses:Food  = 5000.00
			je

			actual_journal = Ledger::Parser.new(entry).parse
			assert_equal 1, actual_journal.length

			actual_journal_entry = actual_journal.journal_entries.first
			expected_journal_entry = Ledger::JournalEntry.new(
				date: Date.new(2020, 1, 1),
				description: 'Uber Eats',
				book_entries: [
					Ledger::BookEntry.new(
						account: 'Assets:Checking', 
						amount: Money.new(123.23), 
						balance_assertion: Money.new(123.23),
						id: '64001023.skljsdkfjsdlkjf'
					),
					Ledger::BookEntry.new(account: 'Expenses:Food', amount: Money.new(-123.23), balance_assertion: Money.new(5000)),
				]	
			)
			assert_equal expected_journal_entry, actual_journal_entry
		end	

		def test_parses_multiple_transaction_ids
			entry = <<-je
2020-01-01 Uber Eats
	Assets:Checking  123.23 = 123.23 ; tid:64001023.skljsdkfjsdlkjf
	Expenses:Food  = 5000.00                     ; tid:12313.12313123123
			je

			actual_journal = Ledger::Parser.new(entry).parse
			assert_equal 1, actual_journal.length

			actual_journal_entry = actual_journal.journal_entries.first
			expected_journal_entry = Ledger::JournalEntry.new(
				date: Date.new(2020, 1, 1),
				description: 'Uber Eats',
				book_entries: [
					Ledger::BookEntry.new(
						account: 'Assets:Checking', 
						amount: Money.new(123.23), 
						balance_assertion: Money.new(123.23),
						id: '64001023.skljsdkfjsdlkjf'
					),
					Ledger::BookEntry.new(
						account: 'Expenses:Food', 
						amount: Money.new(-123.23),
						balance_assertion: Money.new(5000),
						id: '12313.12313123123'
					),
				]	
			)
			assert_equal expected_journal_entry, actual_journal_entry
		end	
	end
end
