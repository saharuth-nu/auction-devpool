# เงื่อนไขการใช้งานและนโยบายความเป็นส่วนตัว (AUTH-19) ต้องเปิดอ่านได้ก่อนสมัคร จึงไม่ต้อง login
class TermsController < ApplicationController
  allow_unauthenticated_access only: :show

  def show; end
end
