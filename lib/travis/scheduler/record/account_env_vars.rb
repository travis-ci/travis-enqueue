# frozen_string_literal: true

class AccountEnvVars < ActiveRecord::Base
  serialize :value, Travis::EncryptedColumn.new
  belongs_to :owner, polymorphic: true
end
