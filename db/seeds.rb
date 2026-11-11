# ข้อมูลตั้งต้นที่ทุก environment ต้องมี ต้องรันซ้ำได้โดยไม่เปลี่ยนผล (idempotent) · รันด้วย bin/rails db:seed
# แต่ละเรื่องแยกไฟล์ใน db/seeds/ (เรียงตามชื่อไฟล์) เพื่อให้หลายคนเพิ่ม seed พร้อมกันได้โดยไม่ชนกัน
#   01_admin.rb            admin คนแรก (AUTH-09)
#   02_auction_methods.rb  วิธีประมูล first_price (METH-04/07)
Dir[Rails.root.join("db/seeds/*.rb")].sort.each { |file| load file }
