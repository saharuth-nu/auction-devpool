# ยื่นราคา (BID-01..05, BID-20, BID-21, #65) — การตรวจทั้งหมดอยู่ที่ PlaceBid ที่นี่แค่รับ request และตอบผู้ใช้
#
# เวลา สิทธิ์ ช่วงราคา และ "ยื่นครั้งเดียว" ตัดสินที่เซิร์ฟเวอร์เสมอ: ขั้นยืนยันและการตรวจช่วงราคาฝั่งเบราว์เซอร์
# เป็นแค่ความสะดวก ไม่ขยายเวลาและไม่แทนการตรวจจริง (BID-20) ผู้ที่ยังไม่ผ่านตรวจถูก QualificationGate ส่งไปหน้าสถานะ
class BidsController < ApplicationController
  allow_roles :bidder

  def create
    lot = Lot.find(params[:lot_id])
    result = PlaceBid.call(user: current_user, lot: lot, amount: amount_param)

    if result.ok?
      redirect_to back_path(lot), status: :see_other,
                  notice: "ยื่นราคา #{helpers.baht(result.bid.amount)} เรียบร้อยแล้ว ยื่นแล้วแก้ไขหรือถอนไม่ได้"
    else
      redirect_to back_path(lot), status: :see_other, alert: result.message
    end
  end

  private

  def amount_param
    params.fetch(:bid, {}).permit(:amount)[:amount]
  end

  # กลับห้องประมูลถ้า event ยังไม่จบ ไม่เช่นนั้นไปการประมูลของฉัน
  def back_path(lot)
    event = lot.auction_event
    AuctionEvent.unfinished.exists?(event.id) ? auction_event_room_path(event) : my_auctions_path
  end
end
