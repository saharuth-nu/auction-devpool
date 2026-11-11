# ห้องประมูล (ROOM-*)
# กฎลบ/ลดจำนวนเมื่อมี event ที่ยังไม่จบ (ROOM-03/04) ทำต่อใน #46 (มี AuctionEvent แล้ว)
class Room < ApplicationRecord
  include Archivable

  has_many :auction_events, dependent: :restrict_with_error

  validates :name, presence: true
  validates :max_participants, :max_items, numericality: { only_integer: true, greater_than: 0 }
end
