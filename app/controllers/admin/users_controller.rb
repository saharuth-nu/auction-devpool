# รายชื่อผู้ใช้ทั้งหมด (ADM-01) และหน้ารายละเอียดผู้ใช้ (ADM-02) — task #41
# ค้นหาด้วย username / fullname / email · กรองตามสถานะคุณสมบัติและการระงับ · แบ่งหน้า
class Admin::UsersController < Admin::BaseController
  include Paginated

  PER_PAGE = 25

  def index
    @filters = params.permit(:q, :qualification_status, :suspension).to_h.symbolize_keys
    @users, @pagination = paginate(User.directory(@filters), per: PER_PAGE)
  end

  def show
    @user = User.bidder.find(params[:id])
    @submissions = @user.qualification_submissions.newest_first.includes(:assets, :reviewed_by)
    @suspension_events = @user.suspension_events.newest_first.includes(:admin)
  end
end
