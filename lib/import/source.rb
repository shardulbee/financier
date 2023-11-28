# typed: strict
# frozen_string_literal: true

require 'money'
require 'sorbet-runtime'

module Import
  module Source
    extend(T::Sig)
    extend(T::Helpers)

    interface!

    sig {abstract.returns(Account)}
    def account; end

    sig { abstract.returns(Balance) }
    def balance; end

    sig { abstract.returns(T::Array[Transaction]) }
    def transactions; end
  end
end
