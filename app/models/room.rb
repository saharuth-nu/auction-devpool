# ห้องประมูล (ROOM-*)
# กฎลบ/ลดจำนวนเมื่อมี event ที่ยังไม่จบ (ROOM-03/04) รอโมเดล AuctionEvent (#53)
class Room < ApplicationRecord
  include Archivable

  validates :name, presence: true
  validates :max_participants, :max_items, numericality: { only_integer: true, greater_than: 0 }
end
