# หน้า "การประมูลของฉัน" (USR-16, issue #62): event ที่ผู้ใช้เข้าร่วม แยก ยังไม่เริ่ม / กำลังประมูล / จบแล้ว
class MyAuctionsController < ApplicationController
  allow_roles :bidder

  def index
    @auctions = MyAuctions.for(current_user)
    # lot ที่ยังเปิดดูหน้ารายละเอียดได้ (ลิงก์ได้) · ที่เหลือแสดงเป็นข้อความ
    @linkable_lot_ids = AuctionListing.lots.where(id: @auctions.lots.map(&:id)).pluck(:id).to_set
  end
end
