# login ของ admin (AUTH-01) ใช้ logic เดียวกับผู้ใช้ แต่รับเฉพาะบัญชี role admin
class Admin::SessionsController < SessionsController
  private

  def expected_role = "admin"
  def form_url = admin_login_path
  def page_title = "เข้าสู่ระบบผู้ดูแล"
end
