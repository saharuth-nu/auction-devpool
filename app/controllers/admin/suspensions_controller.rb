# ระงับ / ยกเลิกระงับบัญชีผู้ใช้ — task #38
# SUSP-01 เหตุผลบังคับ + ขั้นยืนยัน · SUSP-07 ยกเลิกแล้วกลับสถานะเดิม · SUSP-08/NFR-17 บันทึกประวัติ + audit log
# SUSP-09 ใช้กับ bidder เท่านั้น (admin ใช้ DisablementsController) · ผล login/session (SUSP-02) อยู่ใน Authentication
class Admin::SuspensionsController < Admin::BaseController
  before_action :set_user

  def new; end

  def create
    @user.suspend!(by: current_user, reason: reason_param)
    redirect_to admin_user_path(@user), status: :see_other, notice: "ระงับบัญชี “#{@user.username}” แล้ว"
  rescue ActiveRecord::RecordInvalid => e
    @reason_error = e.record.errors[:reason].first
    render :new, status: :unprocessable_entity
  rescue User::Suspension::Error => e
    redirect_to admin_user_path(@user), status: :see_other, alert: e.message
  end

  def destroy
    @user.unsuspend!(by: current_user, reason: reason_param)
    redirect_to admin_user_path(@user), status: :see_other, notice: "ยกเลิกการระงับ “#{@user.username}” แล้ว"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_user_path(@user), status: :see_other,
                alert: "ยกเลิกการระงับไม่สำเร็จ: เหตุผล#{e.record.errors[:reason].first}"
  rescue User::Suspension::Error => e
    redirect_to admin_user_path(@user), status: :see_other, alert: e.message
  end

  private

  def set_user
    @user = User.bidder.find(params[:user_id])
  end

  def reason_param
    params.dig(:suspension, :reason).to_s
  end
end
