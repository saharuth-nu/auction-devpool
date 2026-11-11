# ห้องประมูลของ event (USR-08, USR-09, USR-10, issue #60)
#
# เข้าห้องได้เฉพาะช่วง [เวลาเริ่ม, เวลาสิ้นสุด] ของ event (EVT-06: เวลาสิ้นสุดคือเวลาปิดห้อง) ตัดสินด้วยเวลาของเซิร์ฟเวอร์ (NFR-03)
# ห้องแสดงสินค้าที่อยู่ในการประมูลนี้ขณะนั้นพร้อมนับถอยหลังถึงเวลาปิดรับราคา และให้เข้าร่วมสินค้าอื่นเพิ่มได้ (USR-10)
#
# O-11 (ยังไม่มีคำตอบทางการ): ผู้ใช้ที่ผ่านตรวจ "ต้องเข้าร่วมสินค้าใดใน event ก่อนจึงเข้าห้องได้" หรือไม่
# ตอนนี้ตีความตาม USR-08 ว่า X = ปฏิเสธข้อกำหนดนี้ ผู้ใช้ที่ผ่านตรวจทุกคนเข้าห้องได้เมื่อถึงเวลา
# ถ้าทีมตอบเป็นอีกทาง ให้เปลี่ยนที่ #may_enter? จุดเดียว (เช่น && Participation.joined?(current_user, event))
class AuctionRoomsController < ApplicationController
  allow_roles :bidder

  def show
    @event = AuctionEvent.unfinished.includes(:room, :auction_method).find(params[:auction_event_id])
    return redirect_to(my_auctions_path, alert: closed_message(@event)) unless may_enter?(@event)

    @lots = @event.lots.pending.joins(:item).merge(Item.active)
                  .includes(item: { images_attachments: :blob }).order(:id).to_a
    @joined_lot_ids = Participation.active.where(user: current_user, lot_id: @lots.map(&:id)).pluck(:lot_id).to_set
    @participants = Participation.participants_count(@event)
    # เต็ม = ห้องเต็มและผู้ใช้ยังไม่ได้เป็นผู้เข้าร่วมของ event นี้ (คนเดิมเข้าร่วมสินค้าเพิ่มได้แม้เต็ม, USR-07)
    @full = !Participation.joined?(current_user, @event) && Participation.full?(@event)
  end

  private
    # USR-08 / EVT-06: ถึงเวลาเริ่มแล้ว และยังไม่เลยเวลาปิดห้อง
    def may_enter?(event)
      Clock.within?(event.starts_at, event.ends_at)
    end

    def closed_message(event)
      if Clock.reached?(event.starts_at)
        "ห้องประมูลปิดแล้ว"
      else
        "ห้องประมูลจะเปิดเมื่อถึงเวลาเริ่ม (#{helpers.display_time(event.starts_at)})"
      end
    end
end
