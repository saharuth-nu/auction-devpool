# กวาดซ้ำ: สรุปผลทุก event ที่เลยเวลาปิดรับราคาแล้วแต่ยังไม่สรุป (BID-06, NFR-06)
# กันกรณี job ที่ตั้งเวลาไว้หลุด หรือเซิร์ฟเวอร์รีสตาร์ท · ตั้งให้รันทุกนาทีใน config/recurring.yml
class SettleDueAuctionEventsJob < ApplicationJob
  queue_as :default

  def perform
    AuctionEvent.due_to_settle.each(&:settle!)
  end
end
