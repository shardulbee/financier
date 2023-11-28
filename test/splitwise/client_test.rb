# typed: true
# frozen_string_literal: true

require 'test_helper'
require 'splitwise/client'

module Splitwise
	class ExpenseTest < Minitest::Test
		DATE = Date.today

		def test_valid_false_because_paid_not_equal_to_cost
			expense = Expense.new(
				cost: Money.new(1),
				date: DATE,
				description: 'test',
				expense_shares: [
					ExpenseShare.new(user_id: 1, paid: Money.new(1), owes: Money.new(0.5)),
					ExpenseShare.new(user_id: 2, paid: Money.new(1), owes: Money.new(0.5)),
				]
			)
			refute expense.valid?
		end

		def test_valid_false_because_paid_not_equal_to_owes
			expense = Expense.new(
				cost: Money.new(1),
				date: DATE,
				description: 'test',
				expense_shares: [
					ExpenseShare.new(user_id: 1, paid: Money.new(1), owes: Money.new(0.3)),
					ExpenseShare.new(user_id: 2, paid: Money.new(0), owes: Money.new(0.5)),
				]
			)
			refute expense.valid?
		end

		def test_valid_true_because_paid_not_equal_to_owes
			expense = Expense.new(
				cost: Money.new(1),
				date: DATE,
				description: 'test',
				expense_shares: [
					ExpenseShare.new(user_id: 1, paid: Money.new(1), owes: Money.new(0.5)),
					ExpenseShare.new(user_id: 2, paid: Money.new(0), owes: Money.new(0.5)),
				]
			)
			assert expense.valid?
		end

		def test_serialize
			actual = Expense.new(
				cost: Money.new(1),
				date: DATE,
				description: 'test',
				expense_shares: [
					ExpenseShare.new(user_id: 1, paid: Money.new(1), owes: Money.new(0.5)),
					ExpenseShare.new(user_id: 2, paid: Money.new(0), owes: Money.new(0.5)),
				]
			).serialize
			expected = {
				date: DATE.to_time.to_datetime.iso8601,
				cost: '1.00',
				description: 'test',
				group_id: 0,
				payment: false,
				users__0__user_id: 1,
				users__0__paid_share: '1.00',
				users__0__owed_share: '0.50',
				users__1__user_id: 2,
				users__1__paid_share: '0.00',
				users__1__owed_share: '0.50',
			}

			assert_equal expected, actual
		end
	end

	class ClientTest < Minitest::Test
		DATE = Date.today
		def test_create_expense
			expense = Expense.new(
				cost: Money.new(1),
				date: DATE,
				description: 'test',
				expense_shares: [
					ExpenseShare.new(user_id: 1, paid: Money.new(1), owes: Money.new(0.5)),
					ExpenseShare.new(user_id: 2, paid: Money.new(0), owes: Money.new(0.5)),
				]
			)
			stub_request(:post, 'https://secure.splitwise.com/api/v3.0/create_expense')
				.with(
					headers: {
						'Authorization': 'Bearer an_auth_token',
						'Content-Type': 'application/json'
					},
					body: expense.serialize.to_json
				)
			Client.new(auth_token: 'an_auth_token').create_expense(expense)
		end

		def test_create_expense_raises_if_expense_not_valid
			expense = Expense.new(
				cost: Money.new(2),
				date: DATE,
				description: 'test',
				expense_shares: [
					ExpenseShare.new(user_id: 1, paid: Money.new(1), owes: Money.new(0.5)),
					ExpenseShare.new(user_id: 2, paid: Money.new(0), owes: Money.new(0.5)),
				]
			)

			assert_raises do
				Client.new(auth_token: 'an_auth_token').create_expense(expense)
			end
		end
	end
end
