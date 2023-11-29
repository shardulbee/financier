# Financier

## Background

This was a CLI tool I hacked on to automatically look for QFX files from my Downloads folder and ingest them into my double-entry accounting system (hledger file). This project has been sunset because I can't get my wife to see the light that is [plain text accounting](https://web.archive.org/web/20231127155732/https://plaintextaccounting.org/)

## Usage

Most of the code is bespoke to me but if you're interested, the entrypoint for the tool is at `bin/process-ledger`. You will need to install the required gems with `bundle install` before running the script.

`process-ledger` takes a single parameter which should be `test` or `production`. `test` will run the script on the test ledger and OFX data in the `./data` directory. It will iterate over all the transactions in OFX files and allow you to categorize them and send transactions to Splitwise. If you do decide to try and run the script, splitting a transaction will not work unless you provide Splitwise API credentials and have the exact same Splitiwse setup that I had.

## Features

- Parse transactions from a OFX/QFX file, book them to the correct `hledger` physical account, and categorize them to another account
- Best-effort deduplication of ingested transactions
- Splitwise integration
    - Split transactions 50/50 with someone else during categorization (useful if you split expenses with a roommate or partner)
    - Ingest transactions from Splitwise to update your view of assets/liabilities to others
- Integration with [beeminder](https://www.beeminder.com/overview) to make sure you take care of your financial hygeine
- Testmode/Production setups
