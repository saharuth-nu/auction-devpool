# สินค้าหนึ่งชิ้นใน event หนึ่ง เก็บผลของชิ้นนั้น
# pending = ยังไม่จบ · sold / unsold = ผลหลังปิด (#66, #67) · cancelled = event ถูกยกเลิก
class Lot < ApplicationRecord
  enum :status, {
    pending: "pending",
    sold: "sold",
    unsold: "unsold",
    cancelled: "cancelled"
  }

  belongs_to :auction_event
  belongs_to :item
  # ราคาที่ยื่น (BID-13): ลบ lot ที่มีราคาที่ยื่นไว้ไม่ได้ (NFR-19) · winning_bid คือราคาที่ชนะตอนปิดประมูล (#66)
  has_many :bids, dependent: :restrict_with_error
  belongs_to :winning_bid, class_name: "Bid", optional: true

  validates :item_id, uniqueness: { scope: :auction_event_id, message: "อยู่ในการประมูลนี้แล้ว" }
  validates :winning_price, numericality: { greater_than: 0 }, allow_nil: true
  validates :winning_price, presence: true, if: :sold?
  validate :item_in_one_unfinished_event, if: :pending?

  before_destroy :ensure_event_deletable

  private
    # ITEM-10: DB บังคับด้วย unique index แบบมีเงื่อนไข ที่นี่ให้ข้อความ error ที่อ่านรู้เรื่อง
    def item_in_one_unfinished_event
      return if item_id.blank?
      return unless Lot.pending.where(item_id: item_id).where.not(id: id).exists?

      errors.add(:item, :in_other_event, message: "อยู่ในการประมูลอื่นที่ยังไม่จบ")
    end

    def ensure_event_deletable
      return if auction_event.scheduled?

      errors.add(:base, :not_deletable, message: "ลบสินค้าออกได้เฉพาะการประมูลที่ยังไม่เริ่ม")
      throw :abort
    end
end
