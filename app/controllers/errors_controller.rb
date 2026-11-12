# หน้า error ภาษาไทยตามมาตรฐาน UI (NFR-20) ใช้เป็น config.exceptions_app
# ไม่สืบทอด ApplicationController และไม่แตะฐานข้อมูลหรือ session เลย: หน้านี้ต้องแสดงได้แม้ DB ล่ม (500)
class ErrorsController < ActionController::Base
  layout "error"

  PAGES = {
    404 => [ "ไม่พบหน้าที่ต้องการ", "หน้านี้อาจถูกย้ายหรือลบไปแล้ว หรือคุณไม่มีสิทธิ์เห็นหน้านี้" ],
    422 => [ "ส่งข้อมูลไม่สำเร็จ", "คำขอของคุณไม่ถูกต้องหรือหมดอายุ กรุณากลับไปยังหน้าก่อนหน้าแล้วลองใหม่อีกครั้ง" ],
    500 => [ "ระบบขัดข้องชั่วคราว", "ขออภัยในความไม่สะดวก ทีมงานได้รับแจ้งแล้ว กรุณาลองใหม่อีกครั้งในอีกสักครู่" ]
  }.freeze

  def show
    status = PAGES.key?(request.path[1..].to_i) ? request.path[1..].to_i : 500
    @title, @message = PAGES.fetch(status)
    render :show, status: status, formats: :html
  end
end
