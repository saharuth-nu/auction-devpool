# ห้องประมูล (ROOM-*)
# ลบห้องที่มี event อ้างถึงไม่ได้ (ROOM-03/05, NFR-19) ใช้เก็บถาวรแทน
class Room < ApplicationRecord
  include Archivable

  has_many :auction_events, dependent: :restrict_with_error

  validates :name, presence: true
  validates :max_participants, :max_items, numericality: { only_integer: true, greater_than: 0 }
  validate :max_items_cover_unfinished_events, on: :update, if: :will_save_change_to_max_items?
  # TODO(ROOM-04): max_participants ต้องไม่ต่ำกว่าผู้เข้าร่วมใน event ที่ยังไม่จบ (รอโมเดล Participation #59)

  # จำนวนสินค้ามากที่สุดใน event เดียวของห้องนี้ ที่ยังไม่จบ
  def max_items_in_use
    auction_events.unfinished.joins(:lots).group(:id).count.values.max.to_i
  end

  private
    # ROOM-04: ลดจำนวนสินค้าสูงสุดต่ำกว่าที่ event ที่ยังไม่จบใช้อยู่ไม่ได้
    def max_items_cover_unfinished_events
      return unless max_items.is_a?(Integer)

      in_use = max_items_in_use
      return if max_items >= in_use

      errors.add(:max_items, :below_items_in_use,
        message: "ต่ำกว่าจำนวนสินค้าในการประมูลที่ยังไม่จบ (ใช้อยู่ #{in_use} ชิ้น)")
    end
end
