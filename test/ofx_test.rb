# typed: true
# frozen_string_literal: true

require_relative 'test_helper'
require 'import/ofx'

module Import
	class OfxTest < Minitest::Test
		def setup
			@ofx_path = File.expand_path('../../data/td.qfx', __FILE__)
		end

		def test_balance
			ofx = Ofx.new(path: @ofx_path)
			expected = Balance.new(
				amount: Money.new(-3891.55), account: ofx.account, as_of: Date.new(2021, 8, 20)
			)
			assert_equal expected, ofx.balance
		end

		def test_transaction_parsing
			ofx_transactions = <<-ofx
<BANKTRANLIST>
<DTSTART>20210726
<DTEND>20210820020000[-5:EST]
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20210726020000[-5:EST]
<TRNAMT>-5.25
<FITID>21206211949700010
<NAME>PAYEE 123
</STMTTRN>
</BANKTRANLIST>
			ofx
			expected = Import::Transaction.new(
	      payee: 'PAYEE 123',
	      transaction_id: '21206211949700010',
	      account: Import::Account::TDChecking,
	      amount: Money.new(-5.25),
	      date: Date.new(2021, 7, 26),
	      kind: Import::Transaction::Kind::Debit
			)

			write_ofx_file(ofx_transactions) do |file|
				ofx = Ofx.new(path: file.path)
				assert_equal 1, ofx.transactions.length
				assert_equal expected, ofx.transactions.first
			end
		end

		def test_transaction_parsing_stripe_whitespace_in_payee
			ofx_transactions = <<-ofx
<BANKTRANLIST>
<DTSTART>20210726
<DTEND>20210820020000[-5:EST]
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20210726020000[-5:EST]
<TRNAMT>-5.25
<FITID>21206211949700010
<NAME>PAYEE       WITH      LOTS   OF    SPACES
</STMTTRN>
</BANKTRANLIST>
			ofx
			expected = Import::Transaction.new(
	      payee: 'PAYEE WITH LOTS OF SPACES',
	      transaction_id: '21206211949700010',
	      account: Import::Account::TDChecking,
	      amount: Money.new(-5.25),
	      date: Date.new(2021, 7, 26),
	      kind: Import::Transaction::Kind::Debit
			)

			write_ofx_file(ofx_transactions) do |file|
				ofx = Ofx.new(path: file.path)
				assert_equal 1, ofx.transactions.length
				assert_equal expected, ofx.transactions.first
			end
		end

		def test_inspect
			ofx = Ofx.new(path: @ofx_path)
			expected = "<Transactions originating from #{@ofx_path} for account XXXXXXX>"
			assert_equal expected, ofx.inspect
		end

		private

		def write_ofx_file(transactions)
			Tempfile.create('test.ofx') do |f|
				f.write(write_ofx_transactions(transactions))
				f.rewind
				yield(f)
			end
		end
	end
end
