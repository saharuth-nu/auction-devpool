require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AuctionDevpool
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # ภาษาไทย + เวลาไทย (NFR-01, NFR-02)
    # - เวลาเก็บใน DB เป็น UTC เสมอ (ค่าเริ่มต้นของ Rails) แสดงผลเป็นเวลาไทย (Time.zone = Asia/Bangkok)
    # - :en ยังโหลดไว้เป็นตาข่ายรองให้ gem ภายใน แต่ผู้ใช้ไม่เห็น: locale เริ่มต้นคือ :th
    config.time_zone = "Bangkok"
    config.i18n.default_locale = :th
    config.i18n.available_locales = %i[th en]
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
