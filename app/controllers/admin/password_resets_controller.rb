# admin รีเซ็ตรหัสผ่านให้ผู้ใช้หรือ admin คนอื่น (AUTH-12/13/14) แทน "ลืมรหัสผ่าน" ที่อยู่ M2
# ตั้งรหัสชั่วคราวและบังคับเปลี่ยนเมื่อ login ครั้งถัดไป · รีเซ็ตตัวเองไม่ได้
# รหัสชั่วคราวแสดงในหน้าตอบกลับครั้งเดียว ไม่เก็บใน flash/session/log (log กรอง :passw อยู่แล้ว)
# TODO(NFR-17): บันทึก audit log โดยไม่เก็บรหัส (งาน #71 ของสาย B)
class Admin::PasswordResetsController < Admin::BaseController
  def create
    @target = find_target
    temporary = @target.reset_password(by: current_user)
    if temporary
      @temporary_password = temporary
      response.headers["Cache-Control"] = "no-store"
      render :show
    else
      redirect_to admin_admins_path, alert: @target.errors.full_messages.to_sentence
    end
  end

  private

  # /admin/admins/:id/password_reset → admin · /admin/users/:id/password_reset → ผู้ประมูล
  def find_target
    params[:admin_id] ? User.admin.find(params[:admin_id]) : User.bidder.find(params[:user_id])
  end
end
