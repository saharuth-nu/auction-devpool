# วิธีประมูลเดียวที่ทำงานได้จริงใน M1 (METH-04) · 30 วินาทีกำหนดที่นี่ที่เดียว (METH-07)
# สร้างเฉพาะเมื่อยังไม่มี (รันซ้ำไม่เปลี่ยนค่าที่ admin แก้ไว้)
AuctionMethod.find_or_create_by!(code: "first_price") do |method|
  method.name = "ประมูลราคาปิด (First-Price Sealed)"
  method.bidding_seconds = 30
end
