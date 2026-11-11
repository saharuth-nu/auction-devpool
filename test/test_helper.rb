ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    DEFAULT_PASSWORD = "password123"

    def create_bidder(**attrs)
      n = next_user_number
      User.create!({ username: "bidder#{n}", email: "bidder#{n}@example.com", fullname: "ผู้ประมูล #{n}",
                     password: DEFAULT_PASSWORD, password_confirmation: DEFAULT_PASSWORD }.merge(attrs))
    end

    def create_admin(**attrs)
      n = next_user_number
      User.create!({ username: "admin#{n}", role: :admin,
                     password: DEFAULT_PASSWORD, password_confirmation: DEFAULT_PASSWORD }.merge(attrs))
    end

    def next_user_number
      @user_counter = (@user_counter || 0) + 1
      format("%04d", @user_counter)
    end

    # ผู้ประมูลที่ส่งทรัพย์สินและผ่านตรวจแล้ว (QUAL-10)
    def create_approved_bidder(assets: [ { name: "บ้าน", value: "5000" } ], admin: create_admin, **attrs)
      user = create_bidder(**attrs)
      QualificationSubmission.submit(user, assets).approve!(admin)
      user.reload
    end
  end
end

class ActionDispatch::IntegrationTest
  setup { Rails.cache.clear } # rate limit ของ login เก็บใน cache: ล้างให้แต่ละ test เริ่มใหม่

  # login ผ่านหน้าจริง (หน้าแยกตามบทบาท)
  def sign_in(user, password: ActiveSupport::TestCase::DEFAULT_PASSWORD)
    post(user.admin? ? admin_login_path : login_path, params: { login: { username: user.username, password: password } })
  end
end
