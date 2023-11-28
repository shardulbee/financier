# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require 'sorbet-struct-comparable'

module Import
  class Account < T::Enum
    extend(T::Sig)

    enums do
      TDChecking = new('XXXXXXX')
      TDCreditOld = new('XXXXXXXXXXXXXXXX')
      TDCreditNew = new('XXXXXXXXXXXXXXXX')
      TDLoc = new('xxxxxxx')
      SplitwiseJacinthe = new('xxxxxxx')
      AmericanExpress = new('xxxxxxxxxxxxxxxxxxxxx')
      TDInfinitePrivilege = new('xxxxxxxxxxxxxxxx')
    end

    sig {returns(T::Array[Account])}
    def self.real_accounts
      [
        TDChecking,
        TDCreditNew,
        TDLoc,
        AmericanExpress,
        TDInfinitePrivilege
      ]
    end

    sig { returns(String) }
    def ledger_account
    	case self
    	when TDChecking
    		'Assets:Checking:TD'
    	when TDCreditOld, TDCreditNew
    		'Liabilities:InfiniteVisa'
    	when TDLoc
    		'Liabilities:LOC'
      when SplitwiseJacinthe
        'Assets:Reimbursements:Splitwise:Jacinthe'
      when AmericanExpress
    		'Liabilities:Amex'
      when TDInfinitePrivilege
        'Liabilities:VisaInfinitePrivilege'
    	else
    		T.absurd(self)
    	end
    end
  end

  class Balance < T::Struct
    extend(T::Sig)
    include(T::Struct::ActsAsComparable)

    const :account, Account
    const :amount, Money
    const :as_of, Date

    sig {returns(String)}
    def ledger_id
      "#{account.serialize}.#{as_of.strftime('%Y%m%d')}"
    end
  end

  class Transaction < T::Struct
    include(T::Struct::ActsAsComparable)
    extend(T::Sig)

    class Kind < T::Enum
      extend(T::Sig)
      enums do
        Debit = new('debit')
        Credit = new('credit')
        Assertion = new('assertion')
      end

      sig { returns(T.nilable(String)) }
      def destination_ledger_account
        case self
        when Debit
          'expenses:unknown'
        when Credit
          'income:unknown'
        when Assertion
          nil
        else
          T.absurd(self)
        end
      end
    end

    const :transaction_id, String
    const :account, Account
    const :payee, String
    const :amount, Money
    const :date, Date
    const :kind, Kind

    sig { returns(String) }
    def full_id
      "#{account.serialize}.#{transaction_id}"
    end

    sig { returns(String) }
    def source_ledger_account
      account.ledger_account
    end

    sig { returns(T.nilable(String)) }
    def destination_ledger_account
      kind.destination_ledger_account
    end
  end
end
