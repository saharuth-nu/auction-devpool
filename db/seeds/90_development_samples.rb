# ข้อมูลตัวอย่างสำหรับลองระบบในเครื่อง (development เท่านั้น: ไม่รันใน production และ test)
# รันด้วย bin/rails db:seed · รันซ้ำได้ผลเดิม (หาด้วยชื่อ/username ก่อนสร้าง ไม่เปลี่ยนรหัสผ่านของบัญชีที่มีอยู่)
#
# มีอะไรบ้าง
#   ผู้ประมูล 5 คน ครบทุกสถานะคุณสมบัติ (รหัสผ่านตัวอย่างอยู่ที่ SAMPLE_PASSWORD ด้านล่าง ใช้เฉพาะ dev)
#     somchai    ผ่านตรวจ เพดานราคา 5,000,000 บาท
#     somying    ผ่านตรวจ เพดานราคา 1,000,000 บาท
#     waiting    รอ admin ตรวจ (ส่งทรัพย์สินแล้ว)
#     newbie     รอกรอกทรัพย์สิน (เพิ่งสมัคร)
#     rejected1  ไม่ผ่าน (มีเหตุผล)
#   ห้องประมูล 2 ห้อง · สินค้า 8 ชิ้น (พร้อมขาย 7, รออนุมัติ 1) · การประมูล (event) 2 รอบที่ยังไม่เริ่ม
#   ยังไม่มีรูปสินค้า (หน้าจอแสดง "ไม่มีรูป") ใส่ผ่านหน้า admin ได้
#
# admin คือบัญชีจาก db/seeds/01_admin.rb (ตั้ง ADMIN_USERNAME / ADMIN_PASSWORD ก่อนรัน seed ครั้งแรกได้)
return unless Rails.env.development?

SAMPLE_PASSWORD = ENV.fetch("SAMPLE_PASSWORD", "password123")

admin = User.admin.first or raise "ไม่พบ admin (db/seeds/01_admin.rb ต้องรันก่อน)"
first_price = AuctionMethod.find_by(code: "first_price") or raise "ไม่พบวิธีประมูล first_price (db/seeds/02_auction_methods.rb)"

def sample_bidder(username, fullname)
  User.find_by(username: username) || User.create!(
    username: username, fullname: fullname, email: "#{username}@example.com",
    password: SAMPLE_PASSWORD, password_confirmation: SAMPLE_PASSWORD,
    consented_at: Time.current, terms_version: Terms::VERSION # เหมือนสมัครผ่านหน้า register (AUTH-19)
  )
end

# ---- ผู้ประมูล: ส่งทรัพย์สินและตรวจผ่าน API เดียวกับที่ระบบใช้จริง (มี audit log)
def submit_assets!(user, rows)
  submission = QualificationSubmission.submit(user, rows)
  raise "ส่งทรัพย์สินของ #{user.username} ไม่ผ่าน: #{submission.errors.full_messages.to_sentence}" unless submission.persisted?

  submission
end

somchai = sample_bidder("somchai", "สมชาย ใจดี")
if somchai.qualification_submissions.none?
  submit_assets!(somchai, [ { name: "บ้านและที่ดิน", value: "4,200,000" }, { name: "เงินฝากออมทรัพย์", value: "800,000" } ]).approve!(admin)
end

somying = sample_bidder("somying", "สมหญิง รักเรียน")
if somying.qualification_submissions.none?
  submit_assets!(somying, [ { name: "คอนโดมิเนียม", value: "1,000,000" } ]).approve!(admin)
end

waiting = sample_bidder("waiting", "วิไล รอตรวจ")
submit_assets!(waiting, [ { name: "รถยนต์", value: "450,000" } ]) if waiting.qualification_submissions.none?

sample_bidder("newbie", "นิรันดร์ ใหม่ล่าสุด") # รอกรอกทรัพย์สิน

rejected = sample_bidder("rejected1", "ประภา ไม่ผ่าน")
if rejected.qualification_submissions.none?
  submit_assets!(rejected, [ { name: "ทอง", value: "20,000" } ]).reject!(admin, "มูลค่าทรัพย์สินน้อยเกินไป กรุณาตรวจสอบและส่งใหม่")
end

# ---- ห้องประมูล
main_hall = Room.find_by(name: "ห้องประมูลหลัก") || Room.create!(
  name: "ห้องประมูลหลัก", description: "ห้องสำหรับสินค้าทั่วไป", max_participants: 50, max_items: 10
)
collectors = Room.find_by(name: "ห้องของสะสม") || Room.create!(
  name: "ห้องของสะสม", description: "ห้องสำหรับของสะสมและงานศิลปะ", max_participants: 20, max_items: 5
)

# ---- สินค้า (ราคาเริ่มต้น / ราคาขั้นต่ำ reserve เป็นความลับ)
ITEMS = [
  [ "นาฬิกาข้อมือวินเทจ", "นาฬิกาไขลานยุค 1960 สภาพสวย เดินตรง พร้อมกล่องเดิม", 12_000, 18_000, true ],
  [ "สร้อยคอทองคำ 96.5%", "สร้อยทองหนัก 1 บาท ลายโซ่ถัก พร้อมใบรับประกัน", 35_000, 40_000, true ],
  [ "เหรียญที่ระลึก ร.9 ชุดครบ", "ชุดเหรียญที่ระลึกครบ 12 เหรียญ อยู่ในตลับเดิมทุกเหรียญ", 8_000, 9_500, true ],
  [ "ภาพวาดสีน้ำมัน ทิวทัศน์ชนบท", "ภาพวาดสีน้ำมันบนผ้าใบ ขนาด 60x90 ซม. พร้อมกรอบไม้สัก", 25_000, 30_000, true ],
  [ "โคมไฟตั้งโต๊ะ Art Deco", "โคมไฟทองเหลืองสไตล์ Art Deco ใช้งานได้ปกติ", 4_500, 6_000, true ],
  [ "กล้องฟิล์มคลาสสิก", "กล้อง SLR ยุค 1980 พร้อมเลนส์ 50 มม. และกระเป๋าหนัง", 6_000, 7_500, true ],
  [ "รถจักรยานยนต์คลาสสิก", "รถจักรยานยนต์ยุค 1970 บูรณะแล้ว เครื่องยนต์สมบูรณ์ ทะเบียนครบ", 80_000, 120_000, true ],
  [ "ชุดเครื่องแก้วคริสตัล", "ชุดแก้วคริสตัล 24 ใบ (รออนุมัติ ใช้ลองกดอนุมัติในหน้า admin)", 5_000, 8_000, false ]
].freeze

items = ITEMS.to_h do |name, description, starting, reserve, approved|
  item = Item.find_by(name: name) || Item.create!(
    name: name, description: description, starting_price: starting, reserve_price: reserve
  )
  item.approve!(by: admin) if approved && item.awaiting_approval?
  [ name, item ]
end

# ---- การประมูล (event) ที่ยังไม่เริ่ม: เวลาเริ่มอยู่ในอนาคตเสมอเมื่อสร้างครั้งแรก
def sample_event(name, room, method, starts_at, item_list)
  event = AuctionEvent.find_by(name: name) || AuctionEvent.create!(
    name: name, room: room, auction_method: method, starts_at: starts_at, ends_at: starts_at + 2.hours
  )
  item_list.each { |item| Lot.find_or_create_by!(auction_event: event, item: item) }
  event
end

sample_event("ประมูลเครื่องประดับและของสะสม", main_hall, first_price, 2.days.from_now.change(hour: 19, min: 0),
             items.values_at("นาฬิกาข้อมือวินเทจ", "สร้อยคอทองคำ 96.5%", "เหรียญที่ระลึก ร.9 ชุดครบ"))
sample_event("ประมูลงานศิลปะและของเก่า", collectors, first_price, 5.days.from_now.change(hour: 20, min: 0),
             items.values_at("ภาพวาดสีน้ำมัน ทิวทัศน์ชนบท", "โคมไฟตั้งโต๊ะ Art Deco"))

puts "ข้อมูลตัวอย่าง: ผู้ประมูล #{User.bidder.count} คน · ห้อง #{Room.count} · สินค้า #{Item.count} · event #{AuctionEvent.count}"
