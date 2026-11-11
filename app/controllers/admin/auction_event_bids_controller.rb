# หน้า admin ดูราคาที่ผู้ใช้ทุกคนยื่นของแต่ละสินค้าใน event (EVT-09, BID-11, #56)
# ดูได้ทั้งช่วงเปิดรับราคาและหลังปิด · ทุกครั้งที่เปิดดูบันทึก audit log ว่า admin คนไหนดู lot ไหน เมื่อไหร่
# และอยู่ในช่วงเปิดรับราคา (open) หรือหลังปิด (closed) (EVT-12, NFR-17)
# ราคาที่ยื่นเป็นความลับต่อผู้ใช้ทุกคน: หน้านี้เป็นหน้าเดียวที่แสดงราคาของหลายคนพร้อมกัน จึงจำกัดเฉพาะ admin
class Admin::AuctionEventBidsController < Admin::BaseController
  def show
    @event = AuctionEvent.includes(:room, :auction_method).find(params[:id])
    @phase = bidding_open?(@event) ? "open" : "closed"
    @lots = @event.lots.includes(:item, :winning_bid, bids: :user).order(:id).to_a

    @lots.each do |lot|
      AuditLog.record!(admin: current_user, action: "bids.view", target: lot,
                       change_set: { phase: @phase, auction_event_id: @event.id, bids_count: lot.bids.size })
    end
  end

  private

  # เปิดรับราคา = event เริ่มแล้วและยังไม่เลยเวลาปิดรับราคา (นับด้วยนาฬิกาเซิร์ฟเวอร์ ไม่ใช่แค่สถานะ)
  def bidding_open?(event)
    Clock.reached?(event.starts_at) && !Clock.passed?(event.bidding_ends_at) && !event.finished?
  end
end
