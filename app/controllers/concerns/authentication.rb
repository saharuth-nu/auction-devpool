# การยืนยันตัวตนและสิทธิ์กลาง (requirements AUTH-01/02/10/11/16, NFR-07/08)
#
# ทุก controller ที่สืบทอด ApplicationController ถูก "ปฏิเสธโดยค่าเริ่มต้น":
#   1. ต้อง login (ยกเว้นประกาศ allow_unauthenticated_access)
#   2. ถ้าบัญชีถูกบังคับเปลี่ยนรหัสผ่าน ต้องไปหน้าเปลี่ยนรหัสก่อน (ยกเว้น allow_pending_password_change)
#   3. ต้องประกาศ allow_roles ของ controller นั้น ไม่ประกาศ = 403 (หน้าใหม่จึงปลอดภัยโดยอัตโนมัติ)
#
#   class Admin::ThingsController < Admin::BaseController   # Admin::BaseController มี allow_roles :admin อยู่แล้ว
#   class ThingsController < ApplicationController
#     allow_roles :bidder
module Authentication
  extend ActiveSupport::Concern

  ROLE_HOME = { "admin" => :admin_root_path, "bidder" => :root_path }.freeze

  included do
    class_attribute :permitted_roles, default: nil

    before_action :require_authentication
    before_action :require_password_change
    before_action :authorize_role!

    helper_method :authenticated?, :current_user
  end

  class_methods do
    # หน้าที่เข้าได้โดยไม่ต้อง login เช่น หน้า login / register
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      skip_before_action :require_password_change, **options
      skip_before_action :authorize_role!, **options
    end

    # หน้าที่เข้าได้แม้บัญชีถูกบังคับเปลี่ยนรหัสผ่าน (หน้าเปลี่ยนรหัส, logout)
    def allow_pending_password_change(**options)
      skip_before_action :require_password_change, **options
    end

    def allow_roles(*roles)
      self.permitted_roles = roles.flatten.map(&:to_s)
    end
  end

  private

  def authenticated? = resume_session.present?
  def current_user = Current.user

  def require_authentication
    resume_session || request_authentication
  end

  def require_password_change
    redirect_to forced_password_path if Current.user&.must_change_password?
  end

  def authorize_role!
    roles = self.class.permitted_roles
    return if roles&.include?(Current.user&.role)

    render "errors/forbidden", status: :forbidden
  end

  # คืน Session ถ้ายังใช้ได้ ไม่ใช่ (หมดอายุ / ถูกระงับ / ถูกปิดใช้งาน) ให้ลบทิ้งและถือว่ายังไม่ login
  # ตรวจทุก request จึงหมดผลทันทีเมื่อสถานะบัญชีเปลี่ยน (SUSP-02, ADM-08)
  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def find_session_by_cookie
    session_id = cookies.signed[:session_id]
    return if session_id.blank?

    record = Session.includes(:user).find_by(id: session_id)
    return if record.nil?

    if record.expired? || !record.user.active_for_login?
      @session_ended = true # request_authentication จะแจ้งผู้ใช้ว่าต้อง login ใหม่ (NFR-20)
      record.destroy
      cookies.delete(:session_id)
      return
    end
    record
  end

  def request_authentication
    session[:return_to_after_authenticating] = request.fullpath if request.get? || request.head?
    flash[:alert] = "เซสชันของคุณหมดอายุหรือสิ้นสุดแล้ว กรุณาเข้าสู่ระบบอีกครั้ง" if @session_ended
    redirect_to request.path.start_with?("/admin") ? admin_login_path : login_path
  end

  def after_authentication_url(user = Current.user)
    return forced_password_path if user.must_change_password? # ไปหน้าเปลี่ยนรหัสโดยตรง (AUTH-13)

    stored = session.delete(:return_to_after_authenticating).to_s
    # ใช้ปลายทางเดิมเฉพาะที่เป็น path ภายในและเป็นฝั่งเดียวกับบทบาท (กัน open redirect และกันพาผู้ใช้ไป 403)
    return stored if stored.start_with?("/") && !stored.start_with?("//") && stored.start_with?("/admin") == user.admin?

    public_send(ROLE_HOME.fetch(user.role))
  end

  def start_new_session_for(user)
    reset_session # กัน session fixation
    user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |record|
      Current.session = record
      cookies.signed[:session_id] = { value: record.id, httponly: true, same_site: :lax, secure: Rails.env.production? }
    end
  end

  def terminate_session
    Current.session&.destroy
    Current.session = nil
    cookies.delete(:session_id)
  end
end
