# frozen_string_literal: true

class User < ApplicationRecord
  has_passkeys name: :email, display_name: :email
end
