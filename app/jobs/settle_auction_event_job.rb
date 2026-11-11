# สรุปผลการประมูลตอนเลยเวลาปิดรับราคา (BID-06, NFR-06) ตั้งเวลาไว้จาก AuctionEvent#schedule_settlement
#
# job อาจรันก่อนเวลาเล็กน้อย หรือ admin อาจแก้เวลา/วิธีประมูลไปแล้ว:
#   - ยังไม่เลยเวลาปิดรับราคา → ตั้ง job ใหม่ไว้ที่เวลาปัจจุบัน
#   - สรุปแล้ว / ยกเลิก / ยังไม่เริ่ม / ถูกลบ → ไม่ทำอะไร
# AuctionEvent#settle! รันซ้ำได้ผลเดิม (BID-14) จึงปลอดภัยแม้มี job ซ้อนกันหลายตัว
class SettleAuctionEventJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(event_id)
    event = AuctionEvent.find(event_id)
    return unless event.bidding?

    if Clock.passed?(event.bidding_ends_at)
      event.settle!
    else
      self.class.set(wait_until: event.bidding_ends_at + AuctionEvent::SETTLEMENT_DELAY).perform_later(event.id)
    end
  end
end
