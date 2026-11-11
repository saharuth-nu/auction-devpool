# การเข้าร่วมประมูลของผู้ใช้ต่อสินค้า (lot) หนึ่งชิ้น (USR-05, 06, 07)
#
# กติกา:
#   - เข้าร่วมได้เฉพาะ lot ที่ผู้ใช้เห็นได้ (AuctionListing.lots) และยังไม่ปิดรับราคา (O-8: เข้าร่วมเพิ่มได้จนปิดรับราคา)
#   - ผู้ใช้ต้องเป็นผู้ประมูลที่ผ่านการตรวจคุณสมบัติและไม่ถูกระงับ (QUAL-05, SUSP-03)
#   - ครั้งเดียวต่อสินค้า (USR-06): แถวที่ยังไม่ยกเลิกของ (user, lot) มีได้แถวเดียว ทั้งใน model และ unique index
#   - ห้องเต็ม (USR-07): จำนวน "คน" ที่เข้าร่วมใน event ต้องไม่เกิน max_participants ของห้อง · คนที่เข้าร่วมสินค้าอื่นใน
#     event เดียวกันอยู่แล้วนับเป็นคนเดิม เข้าร่วมสินค้าเพิ่มได้แม้ห้องเต็ม
#   - ยกเลิกได้ก่อน event เริ่มเท่านั้น (USR-06) และเป็นการใส่ cancelled_at ไม่ลบแถว (NFR-19)
#
# การเช็คจำนวนคนอยู่ใน transaction ของ save (SQLite เปิด transaction แบบ immediate ใน Rails 8 การเข้าร่วมพร้อมกัน
# จึงต่อคิวกัน) แถวสุดท้ายของห้องจึงไม่หลุดเกินจากการยิงพร้อมกัน
class Participation < ApplicationRecord
  class NotCancellable < StandardError; end

  belongs_to :user
  belongs_to :lot

  scope :active, -> { where(cancelled_at: nil) }
  scope :cancelled, -> { where.not(cancelled_at: nil) }

  validate :user_may_participate, on: :create
  validate :lot_open_for_joining, on: :create
  validate :not_already_joined, on: :create
  validate :event_has_room, on: :create

  class << self
    # จำนวนคน (ไม่ใช่จำนวนสินค้า) ที่เข้าร่วมอยู่ใน event หนึ่ง · นับเฉพาะการเข้าร่วมบน lot ที่ยัง pending
    # (lot ที่ถูกยกเลิก/เอาออกจาก event ไม่ถือที่นั่ง)
    def participants_count(event)
      holding_seat.where(lots: { auction_event_id: event.id }).distinct.count(:user_id)
    end

    # การเข้าร่วมที่ยังถือที่นั่ง: ไม่ยกเลิก และ lot ยังรอการประมูล
    def holding_seat
      active.joins(:lot).merge(Lot.pending)
    end

    def full?(event)
      participants_count(event) >= event.room.max_participants
    end

    def joined?(user, event)
      holding_seat.where(user_id: user.id, lots: { auction_event_id: event.id }).exists?
    end
  end

  def active? = cancelled_at.nil?

  # ยกเลิกได้เฉพาะก่อน event เริ่ม (USR-06)
  def cancellable?
    active? && !Clock.reached?(lot.auction_event.starts_at)
  end

  def cancel!
    raise NotCancellable, "ยกเลิกได้เฉพาะการเข้าร่วมที่ยังไม่ยกเลิกและก่อนการประมูลเริ่ม" unless cancellable?

    update!(cancelled_at: Clock.now)
  end

  private
    def user_may_participate
      return if user.blank?

      errors.add(:base, :not_bidder, message: "เฉพาะผู้ประมูลเท่านั้นที่เข้าร่วมได้") unless user.bidder?
      errors.add(:base, :not_qualified, message: "ต้องผ่านการตรวจสอบคุณสมบัติก่อน") if user.bidder? && !user.qualified?
      errors.add(:base, :suspended, message: "บัญชีถูกระงับ เข้าร่วมประมูลไม่ได้") if user.suspended?
    end

    # สินค้าที่ผู้ใช้เห็นได้ (ชุดเดียวกับหน้าแรกและหน้ารายละเอียด) และยังไม่ปิดรับราคา
    def lot_open_for_joining
      return if lot.blank?

      unless AuctionListing.lots.exists?(id: lot_id) && !Clock.passed?(lot.auction_event.bidding_ends_at)
        errors.add(:base, :lot_closed, message: "สินค้านี้ปิดรับการเข้าร่วมแล้ว")
      end
    end

    def not_already_joined
      return if user.blank? || lot.blank?

      if Participation.active.exists?(user_id: user_id, lot_id: lot_id)
        errors.add(:base, :already_joined, message: "คุณเข้าร่วมสินค้านี้แล้ว")
      end
    end

    def event_has_room
      return if user.blank? || lot.blank?

      event = lot.auction_event
      return if Participation.joined?(user, event) # คนเดิมของ event นี้ ไม่ใช่ที่นั่งใหม่

      errors.add(:base, :event_full, message: "เต็มแล้ว") if Participation.full?(event)
    end
end
