# typed: true
# frozen_string_literal: true

require 'test_helper'
require 'beeminder/client'

module Beeminder
	class ClientTest < Minitest::Test
		DESCRIPTION = 'test'
		AMOUNT = Money.new(1)
		DATE = Date.today
		AUTH_TOKEN = 'this is a token'

		def test_it_submits_expense_with_correct_params
			stub_request(:post, "https://www.beeminder.com/api/v1/users/shardy/goals/blowads/datapoints.json")
				.with(body: {
					comment: DESCRIPTION,
					value: AMOUNT.to_f,
					daystamp: DATE.strftime('%Y%m%d'),
					auth_token: AUTH_TOKEN
				})

			Beeminder::Client.new(auth_token: AUTH_TOKEN).submit_expense(
				description: DESCRIPTION,
				amount: AMOUNT,
				date: DATE
			)
		end
	end
end
