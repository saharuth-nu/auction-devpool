# รายชื่อผู้ใช้ทั้งหมดสำหรับ admin: ค้นหา / กรอง (task #41 · ADM-01)
module User::Directory
  extend ActiveSupport::Concern

  SUSPENSION_FILTERS = %w[suspended active].freeze

  included do
    # ค้นหาบางส่วนของ username / fullname / email (ไม่สนตัวพิมพ์ใหญ่เล็ก)
    scope :search, ->(query) {
      next all if query.blank?

      pattern = "%#{sanitize_sql_like(query.to_s.strip.downcase)}%"
      where("LOWER(users.username) LIKE :q ESCAPE '\\' OR LOWER(users.fullname) LIKE :q ESCAPE '\\' " \
            "OR LOWER(users.email) LIKE :q ESCAPE '\\'", q: pattern)
    }
    scope :with_qualification_status, ->(status) {
      status.present? && qualification_statuses.key?(status.to_s) ? where(qualification_status: status) : all
    }
    scope :with_suspension, ->(filter) {
      case filter.to_s
      when "suspended" then suspended
      when "active" then not_suspended
      else all
      end
    }
  end

  class_methods do
    # ตัวกรองรวมของหน้ารายชื่อผู้ใช้: q, qualification_status, suspension (การแบ่งหน้าทำที่ controller)
    def directory(params = {})
      params = params.to_h.symbolize_keys
      bidder.search(params[:q])
            .with_qualification_status(params[:qualification_status])
            .with_suspension(params[:suspension])
            .order(created_at: :desc, id: :desc)
    end
  end
end
