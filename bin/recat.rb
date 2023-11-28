#!/usr/bin/env ruby
# typed: strict

$LOAD_PATH.unshift(File.expand_path("../../lib", File.realpath(__FILE__)))

require 'environment_configuration'
require 'import/helpers'
require 'ledger/parser'

require 'dotenv/load'
require 'sorbet-runtime'

require 'cli/ui'
CLI::UI::StdoutRouter.enable

config = EnvironmentConfiguration.get(ARGV[0])
journal = Ledger::Parser.parse_dir(config.journal_dir)

journal.journal_entries.each do |je|
  relevant_entry = je.book_entries.find do |be|
    be.account.include?(':Discretionary:')
  end
  next unless relevant_entry

  CLI::UI::Frame.open("Recategorizing") do
    CLI::UI::Frame.open("Current Journal Entry") do
      puts je
    end

    relevant_entry.update(
      account: relevant_entry.account.gsub(/:Discretionary:/, ':')
    )
    true
  end
end

if CLI::UI.confirm('Move on?')
  journal.write(config.journal_dir)
end
