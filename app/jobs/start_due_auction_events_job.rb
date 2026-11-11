# กวาดซ้ำ: เริ่มทุก event ที่ถึงเวลาแล้วแต่ยังไม่เริ่ม (EVT-07)
# กันกรณี job ที่ตั้งเวลาไว้หลุด หรือเซิร์ฟเวอร์รีสตาร์ท · ตั้งให้รันทุกนาทีใน config/recurring.yml
class StartDueAuctionEventsJob < ApplicationJob
  queue_as :default

  def perform
    AuctionEvent.due_to_start.find_each(&:start!)
  end
end
