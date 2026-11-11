# โปรไฟล์ของตนเอง (AUTH-18): แสดงข้อมูล แก้ username ไม่ได้
class ProfilesController < ApplicationController
  allow_roles :admin, :bidder

  def show; end
end
