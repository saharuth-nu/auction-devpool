# ประวัติการกระทำของ admin (ดูได้อย่างเดียว) — task #71
# NFR-18 กรองตาม admin / ประเภทการกระทำ / ช่วงเวลา / สิ่งที่ถูกกระทำ · ไม่มี route แก้หรือลบ
class Admin::AuditLogsController < Admin::BaseController
  include Paginated

  PER_PAGE = 50

  def index
    @filters = params.permit(:admin_id, :action_name, :target_type, :target_id, :from, :to).to_h.symbolize_keys
    @admins = User.admin.order(:username)
    scope = AuditLog.filter(
      admin_id: @filters[:admin_id], action: @filters[:action_name],
      target_type: @filters[:target_type], target_id: @filters[:target_id],
      from: parse_date(@filters[:from])&.beginning_of_day, to: parse_date(@filters[:to])&.end_of_day
    ).includes(:admin, :target)
    @logs, @pagination = paginate(scope, per: PER_PAGE)
  end

  private

  def parse_date(value)
    Date.iso8601(value) if value.present?
  rescue Date::Error
    nil
  end
end
