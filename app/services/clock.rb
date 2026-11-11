# นาฬิกากลางของระบบ (NFR-03)
#
# การตัดสินเรื่องเวลาทุกอย่าง (เริ่มประมูล, ปิดรับราคา, ยื่นทัน, เข้าห้องได้หรือยัง) ต้องใช้เวลาของ "เซิร์ฟเวอร์"
# ผ่านคลาสนี้เท่านั้น ห้ามเอาเวลาที่มาจากเบราว์เซอร์ (params, header, JS) มาตัดสิน
# นับถอยหลังบนหน้าจอเป็นแค่การแสดงผล: ให้เซิร์ฟเวอร์ส่งค่า Clock.remaining ไปให้ แล้วตรวจซ้ำที่เซิร์ฟเวอร์ทุกครั้งที่ยื่นราคา
#
#   Clock.now                              # เวลาปัจจุบัน (ActiveSupport::TimeWithZone, Asia/Bangkok)
#   Clock.reached?(event.starts_at)        # ถึงเวลาแล้ว (เท่ากันนับว่าถึง)
#   Clock.passed?(deadline)                # เลยเวลาไปแล้ว (เท่ากันยังไม่เลย)
#   Clock.within?(starts_at, starts_at + method.bidding_seconds)  # ยื่นทันไหม (BID-02) นับทั้งต้นและปลายช่วง
#   Clock.remaining(deadline)              # เหลืออีกกี่วินาที (Float) ไม่ติดลบ
#
# ตอนทดสอบ ใช้ travel_to / freeze_time ของ Rails ได้เลย (ดู test/services/clock_test.rb)
# เวลาที่ส่งเข้ามาเป็น nil จะ raise ArgumentError ทันที ไม่ตีความเงียบๆ ว่า "ถึงแล้ว" หรือ "ยังไม่ถึง"
class Clock
  class << self
    def now
      Time.current
    end

    def reached?(time)
      now >= time
    end

    def passed?(time)
      now > time
    end

    def within?(from, to)
      raise ArgumentError, "from และ to ต้องไม่เป็น nil" if from.nil? || to.nil?

      current = now
      current >= from && current <= to
    end

    def remaining(deadline)
      raise ArgumentError, "deadline ต้องไม่เป็น nil" if deadline.nil?

      [ deadline - now, 0.0 ].max.to_f
    end
  end
end
