# บังคับเปลี่ยนรหัสผ่านหลัง admin รีเซ็ต (AUTH-13): เข้าได้แม้ must_change_password
# ไม่ต้องกรอกรหัสเดิม (ผู้ใช้เพิ่งได้รหัสชั่วคราวมา) แต่รหัสใหม่ต้องไม่ซ้ำรหัสชั่วคราวและผ่าน AUTH-06
class ForcedPasswordsController < ApplicationController
  allow_roles :admin, :bidder
  allow_pending_password_change
  before_action :redirect_unless_required

  def show
    @user = Current.user
  end

  def update
    @user = Current.user
    if @user.change_password(new_password: forced_params[:password].to_s,
                             confirmation: forced_params[:password_confirmation].to_s,
                             keep_session: Current.session)
      redirect_to after_authentication_url(@user), notice: "ตั้งรหัสผ่านใหม่แล้ว"
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def forced_params
    params.expect(user: %i[password password_confirmation])
  end

  def redirect_unless_required
    redirect_to after_authentication_url unless Current.user.must_change_password?
  end
end
