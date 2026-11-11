# หน้าตัวอย่าง component ทั้งหมดของ Design System (DESIGN.md) ไว้เปิดดูหน้าตาจริงบนมือถือ/เดสก์ท็อป
# เปิดเฉพาะ development/test (ดู config/routes.rb) ไม่บันทึกอะไรจริง: ปุ่มต่างๆ แค่ส่งกลับมาหน้านี้พร้อมข้อความ
#
# ดูบนเครื่อง:  bin/rails server แล้วเปิด http://localhost:3000/styleguide
# ดูบนมือถือ:   เปิด DevTools → Toggle device toolbar หรือเปิดผ่านเครือข่ายเดียวกันด้วย bin/rails server -b 0.0.0.0
class StyleguideController < ApplicationController
  allow_unauthenticated_access

  # โมเดลจำลองสำหรับแสดงฟอร์มและ error
  class Sample
    include ActiveModel::Model
    attr_accessor :name, :room_id, :enabled, :images
    validates :name, presence: true
  end

  def show
    flash.now[:notice] = "(ตัวอย่าง) ทำรายการแล้ว ไม่ได้บันทึกอะไรจริง" unless request.get? || request.head?
    @sample = Sample.new.tap(&:validate)
    @rows = [ [ "นาฬิกาข้อมือวินเทจ 1968", :active, BigDecimal("182000") ], [ "กล้องฟิล์ม Rangefinder", :closed, BigDecimal("36500.5") ] ]
  end
end
