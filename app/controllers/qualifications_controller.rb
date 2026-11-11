# หน้าสถานะคุณสมบัติของผู้ประมูล + ส่ง/แก้ทรัพย์สิน — tasks #34 #35
# QUAL-02 ฟอร์มแสดงทุกครั้งที่ login จนกว่าจะส่งสำเร็จ · QUAL-04/09 ส่งแล้วเป็น "รอ admin ตรวจ"
# QUAL-05 เป็นหน้าเดียวที่ผู้ยังไม่ผ่านเข้าได้ · QUAL-06 เนื้อหาตามสถานะ · QUAL-12/15 ล็อกและเติมรายการรอบก่อน
class QualificationsController < ApplicationController
  allow_roles :bidder
  allow_unqualified_access

  BLANK_ROWS = 3   # แถวว่างเพิ่มให้ทุกครั้ง
  MIN_ROWS = 5

  before_action :redirect_if_qualified

  def show
    @user = Current.user
    @rows = form_rows(@user.can_submit_assets? ? @user.asset_rows_for_resubmission : [])
  end

  def create
    @user = Current.user
    unless @user.can_submit_assets?
      return redirect_to qualification_path, status: :see_other, alert: "ไม่สามารถส่งทรัพย์สินได้ในสถานะปัจจุบัน"
    end

    @submission = QualificationSubmission.submit(@user, assets_params)
    if @submission.persisted?
      redirect_to qualification_path, status: :see_other, notice: "ส่งทรัพย์สินแล้ว อยู่ระหว่างการตรวจสอบคุณสมบัติ"
    else
      @user.reload
      @rows = form_rows(@submission.assets.to_a)
      render :show, status: :unprocessable_entity
    end
  end

  private

  # submission[assets][0][name], submission[assets][0][value], ...
  def assets_params
    params.fetch(:submission, {}).permit(assets: %i[name value]).fetch(:assets, {}).to_h
  end

  def redirect_if_qualified
    redirect_to root_path if Current.user.qualified?
  end

  # แถวของฟอร์ม: รายการเดิม (Asset ที่มี errors หรือ hash จากรอบก่อน) + แถวว่าง ไม่เกิน MAX_ASSETS
  def form_rows(existing)
    rows = existing.map { |row| row.is_a?(Asset) ? row : Asset.new(row) }
    blanks = [ MIN_ROWS - rows.size, BLANK_ROWS ].max
    blanks = [ blanks, QualificationSubmission::MAX_ASSETS - rows.size ].min
    rows + Array.new([ blanks, 0 ].max) { Asset.new }
  end
end
