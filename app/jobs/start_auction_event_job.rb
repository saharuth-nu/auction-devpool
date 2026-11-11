# เริ่มการประมูลตอนถึงเวลา (EVT-07) ตั้งเวลาไว้ที่ starts_at จาก AuctionEvent#schedule_start
#
# job อาจรันก่อนเวลาเล็กน้อย หรือ admin อาจเลื่อนเวลาเริ่มไปแล้ว:
#   - ยังไม่ถึงเวลา → ตั้ง job ใหม่ไว้ที่ starts_at ปัจจุบัน (ไม่ต้องรอ job กวาดซ้ำ ซึ่งช้าได้ถึง 1 นาที เกินช่วงยื่นราคา 30 วินาที)
#   - เริ่มแล้ว / ยกเลิก / ถูกลบ → ไม่ทำอะไร
# AuctionEvent#start! รันซ้ำได้ผลเดิม จึงปลอดภัยแม้มี job ซ้อนกันหลายตัว
class StartAuctionEventJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(event_id)
    event = AuctionEvent.find(event_id)
    return unless event.scheduled?

    if Clock.reached?(event.starts_at)
      event.start!
    else
      self.class.set(wait_until: event.starts_at).perform_later(event.id)
    end
  end
end
