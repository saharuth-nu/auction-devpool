# การประมูลหนึ่งรอบ (EVT-*) ผูกกับห้อง วิธีประมูล เวลา และสินค้า (ผ่าน lots)
#
# สถานะ (EVT-10): ยังไม่เริ่ม → เปิดรับราคา → สรุปผลแล้ว · ยกเลิกได้เฉพาะก่อนเริ่ม (EVT-08)
# เปลี่ยนสถานะผ่าน transition_to! / cancel! เท่านั้น การเปลี่ยนข้ามขั้นถูกปฏิเสธทั้งที่ model
# ส่วนการเริ่ม (สินค้าเป็น "อยู่ระหว่างการประมูล") อยู่ใน #55 และการปิด/คัดผู้ชนะอยู่ใน #66
class AuctionEvent < ApplicationRecord
  class InvalidTransition < StandardError; end

  enum :status, {
    scheduled: "scheduled",
    bidding: "bidding",
    settled: "settled",
    cancelled: "cancelled"
  }

  TRANSITIONS = {
    "scheduled" => %w[bidding cancelled],
    "bidding" => %w[settled],
    "settled" => [],
    "cancelled" => []
  }.freeze

  # แก้ไม่ได้เมื่อ event เริ่มแล้ว (EVT-08)
  LOCKED_ATTRIBUTES = %i[starts_at ends_at room_id auction_method_id].freeze

  belongs_to :room
  belongs_to :auction_method
  has_many :lots, dependent: :destroy
  has_many :items, through: :lots

  # ต้องมาก่อน has_many dependent: :destroy เพื่อกันการลบ lot ของ event ที่ลบไม่ได้
  before_destroy :ensure_deletable, prepend: true

  validates :name, :starts_at, :ends_at, presence: true
  validate :ends_after_bidding_window
  validate :status_transition_allowed, on: :update
  validate :schedule_locked_after_start, on: :update

  scope :unfinished, -> { where(status: %w[scheduled bidding]) }

  # ปิดรับราคาเมื่อครบระยะเวลาของวิธีประมูลนับจากเวลาเริ่ม (BID-02, EVT-06)
  def bidding_ends_at
    starts_at + auction_method.bidding_duration
  end

  # แก้ไข/ยกเลิกได้เฉพาะก่อนเริ่ม (EVT-08)
  def editable?
    scheduled?
  end

  def finished?
    settled? || cancelled?
  end

  def transition_to!(new_status, **attributes)
    unless can_transition_to?(new_status)
      raise InvalidTransition, "เปลี่ยนสถานะจาก #{status} เป็น #{new_status} ไม่ได้"
    end

    update!(status: new_status, **attributes)
  end

  def can_transition_to?(new_status)
    TRANSITIONS.fetch(status).include?(new_status.to_s)
  end

  # ยกเลิกก่อนเริ่ม: lot ที่ยังไม่จบเป็น cancelled เพื่อปล่อยสินค้าไปใส่ event อื่นได้ (ITEM-10)
  def cancel!
    transaction do
      transition_to!(:cancelled, cancelled_at: Time.current)
      lots.pending.find_each { |lot| lot.update!(status: :cancelled) }
    end
  end

  private
    # EVT-05: เวลาสิ้นสุด ≥ เวลาเริ่ม + ระยะเวลายื่นราคา
    def ends_after_bidding_window
      return if starts_at.blank? || ends_at.blank? || auction_method.blank?
      return if ends_at >= bidding_ends_at

      errors.add(:ends_at, :before_bidding_window,
        message: "ต้องไม่เร็วกว่าเวลาเริ่ม + #{auction_method.bidding_seconds} วินาที")
    end

    def status_transition_allowed
      return unless will_save_change_to_status?

      from = status_in_database
      return if TRANSITIONS.fetch(from, []).include?(status)

      errors.add(:status, :invalid_transition, message: "เปลี่ยนจาก #{from} เป็น #{status} ไม่ได้")
    end

    def schedule_locked_after_start
      return if status_in_database == "scheduled"

      LOCKED_ATTRIBUTES.each do |attribute|
        next unless will_save_change_to_attribute?(attribute)

        errors.add(attribute, :locked_after_start, message: "แก้ไม่ได้เมื่อการประมูลเริ่มแล้ว")
      end
    end

    # EVT-08: ลบได้เฉพาะ event ที่ยังไม่เริ่ม (EVT-11 เรื่องผู้เข้าร่วม: FK restrict ของ participations กันไว้)
    def ensure_deletable
      return if status_in_database == "scheduled"

      errors.add(:base, :not_deletable, message: "ลบได้เฉพาะการประมูลที่ยังไม่เริ่ม")
      throw :abort
    end
end
