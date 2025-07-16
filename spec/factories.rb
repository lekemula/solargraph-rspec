FactoryBot.define do
  # Comment!
  factory :user do
    # @return [String]
    example { 'String' }
  end

  factory :fact do
    name { "name :3" }
  end
end

class User
    def user_method_only
    end
end
