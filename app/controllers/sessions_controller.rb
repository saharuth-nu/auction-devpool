# login/logout ของผู้ใช้ (AUTH-02, AUTH-11) — Admin::SessionsController สืบทอดไปใช้กับ admin (AUTH-01)
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  allow_pending_password_change only: :destroy
  allow_roles :admin, :bidder # ใช้กับ destroy (ต้อง login อยู่)
  rate_limit to: 10, within: 3.minutes, only: :create, with: :too_many_attempts # NFR-07
  before_action :redirect_if_signed_in, only: :new

  def new; end

  def create
    user = User.authenticate_by(username: login_params[:username].to_s, password: login_params[:password].to_s)

    # รหัสผ่านถูก แต่บัญชีเป็นอีกบทบาท = ตอบเหมือนรหัสผ่านผิด (ไม่บอกว่ามีบัญชีนี้อยู่ฝั่งอื่น)
    if user.nil? || user.role != expected_role
      reject "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง"
    elsif user.suspended?
      reject "บัญชีของคุณถูกระงับ กรุณาติดต่อผู้ดูแลระบบ"
    elsif user.disabled?
      reject "บัญชีนี้ถูกปิดใช้งาน กรุณาติดต่อผู้ดูแลระบบ"
    else
      return_to = session[:return_to_after_authenticating]
      start_new_session_for user
      session[:return_to_after_authenticating] = return_to
      redirect_to after_authentication_url(user)
    end
  end

  def destroy
    role = Current.user&.role
    terminate_session
    redirect_to(role == "admin" ? admin_login_path : login_path, status: :see_other, notice: "ออกจากระบบแล้ว")
  end

  private

  def expected_role = "bidder"
  def form_url = login_path

  def login_params = params.fetch(:login, {}).permit(:username, :password)

  def reject(message)
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end

  def too_many_attempts
    redirect_to(request.path.start_with?("/admin") ? admin_login_path : login_path,
                alert: "พยายามเข้าสู่ระบบบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่")
  end

  def redirect_if_signed_in
    redirect_to after_authentication_url(Current.user) if resume_session
  end

  helper_method :form_url, :page_title
  def page_title = "เข้าสู่ระบบ"
end
