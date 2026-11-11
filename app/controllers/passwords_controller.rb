# เปลี่ยนรหัสผ่านทั่วไป (AUTH-18): ต้องกรอกรหัสเดิม + รหัสใหม่ + ยืนยัน (ผ่านกฎ AUTH-06)
# สำเร็จแล้ว session อื่นของบัญชีนี้หมดผล (คงเฉพาะ session ปัจจุบัน)
class PasswordsController < ApplicationController
  allow_roles :admin, :bidder

  def edit
    @user = Current.user
  end

  def update
    user = Current.user
    if user.change_password(current: password_params[:current_password].to_s,
                            new_password: password_params[:password].to_s,
                            confirmation: password_params[:password_confirmation].to_s,
                            keep_session: Current.session)
      redirect_to profile_path, notice: "เปลี่ยนรหัสผ่านแล้ว"
    else
      @user = user
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.expect(user: %i[current_password password password_confirmation])
  end
end
