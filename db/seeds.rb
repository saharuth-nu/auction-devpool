# ข้อมูลตั้งต้นที่ทุก environment ต้องมี รันซ้ำได้ (idempotent)

# วิธีประมูลเดียวที่ทำงานได้จริงใน M1 (METH-04) · 30 วินาทีกำหนดที่นี่ที่เดียว (METH-07)
AuctionMethod.find_or_create_by!(code: "first_price") do |method|
  method.name = "ประมูลราคาปิด (First-Price Sealed)"
  method.bidding_seconds = 30
end
