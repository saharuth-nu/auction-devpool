# หน้าแรกของผู้ใช้ (USR-01..03): banner คงที่ + รายการสินค้าที่อยู่ใน event ที่ยังไม่สรุปผล
class HomeController < ApplicationController
  allow_roles :admin, :bidder

  def show
    return redirect_to admin_root_path if Current.user.admin?

    @listings = AuctionListing.entries
  end
end
