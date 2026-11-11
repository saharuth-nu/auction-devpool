# สมัครสมาชิกผู้ใช้ (AUTH-03) และ login ให้อัตโนมัติ (AUTH-03a)
# หมายเหตุ: ต้องพาไปหน้าสถานะ/ฟอร์มกรอกทรัพย์สิน (งาน #35 ของสาย B) ตอนนี้ไปหน้าแรก
class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "พยายามสมัครบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่" }
  before_action -> { redirect_to root_path if resume_session }

  def new
    @user = User.new
  end

  def create
    # role กำหนดโดยระบบเสมอ ไม่รับจากฟอร์ม (กันสมัครเป็น admin)
    @user = User.new(registration_params.merge(role: :bidder))
    if @user.save
      start_new_session_for @user
      redirect_to root_path, notice: "สมัครสมาชิกสำเร็จ"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.expect(user: %i[fullname username email password password_confirmation])
  end
end
