# ห้องประมูล (ROOM-*)
# ลบห้องที่มี event อ้างถึงไม่ได้ (ROOM-03/05, NFR-19) ใช้เก็บถาวรแทน
class Room < ApplicationRecord
  include Archivable

  has_many :auction_events, dependent: :restrict_with_error

  validates :name, presence: true
  validates :max_participants, :max_items, numericality: { only_integer: true, greater_than: 0 }
  validate :max_items_cover_unfinished_events, on: :update, if: :will_save_change_to_max_items?
  validate :max_participants_cover_unfinished_events, on: :update, if: :will_save_change_to_max_participants?

  # จำนวนสินค้ามากที่สุดใน event เดียวของห้องนี้ ที่ยังไม่จบ
  def max_items_in_use
    auction_events.unfinished.joins(:lots).group(:id).count.values.max.to_i
  end

  # จำนวนคนมากที่สุดใน event เดียวของห้องนี้ ที่ยังไม่จบ
  def max_participants_in_use
    Participation.holding_seat.joins(lot: :auction_event).merge(AuctionEvent.unfinished)
                 .where(auction_events: { room_id: id }).group("auction_events.id").distinct.count(:user_id).values.max.to_i
  end

  private
    # ROOM-04: ลดจำนวนผู้เข้าร่วมสูงสุดต่ำกว่าที่ event ที่ยังไม่จบมีอยู่ไม่ได้
    def max_participants_cover_unfinished_events
      return unless max_participants.is_a?(Integer)

      in_use = max_participants_in_use
      return if max_participants >= in_use

      errors.add(:max_participants, :below_participants_in_use,
        message: "ต่ำกว่าจำนวนผู้เข้าร่วมในการประมูลที่ยังไม่จบ (มีอยู่ #{in_use} คน)")
    end

    # ROOM-04: ลดจำนวนสินค้าสูงสุดต่ำกว่าที่ event ที่ยังไม่จบใช้อยู่ไม่ได้
    def max_items_cover_unfinished_events
      return unless max_items.is_a?(Integer)

      in_use = max_items_in_use
      return if max_items >= in_use

      errors.add(:max_items, :below_items_in_use,
        message: "ต่ำกว่าจำนวนสินค้าในการประมูลที่ยังไม่จบ (ใช้อยู่ #{in_use} ชิ้น)")
    end
end
