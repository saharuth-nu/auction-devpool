# หน้าแรกชั่วคราวของผู้ใช้ (หน้าจริงพร้อมรายการสินค้าเป็นงาน #57 ของสาย E: แทนไฟล์นี้และ view ได้เลย)
class HomeController < ApplicationController
  allow_roles :admin, :bidder

  def show
    redirect_to admin_root_path if Current.user.admin?
  end
end
