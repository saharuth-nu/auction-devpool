# การประมูลหนึ่งรอบ (EVT-*) ผูกกับห้อง วิธีประมูล เวลา และสินค้า (ผ่าน lots)
#
# สถานะ (EVT-10): ยังไม่เริ่ม → เปิดรับราคา → สรุปผลแล้ว · ยกเลิกได้เฉพาะก่อนเริ่ม (EVT-08)
# เปลี่ยนสถานะผ่าน transition_to! / cancel! เท่านั้น การเปลี่ยนข้ามขั้นถูกปฏิเสธทั้งที่ model
# การเริ่ม: start! (EVT-07, #55) · การปิด/คัดผู้ชนะอยู่ใน #66
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

  # ตั้งจากฟอร์ม: id ของสินค้าที่เลือก บันทึกเป็น lot หลัง save (ดู sync_lots)
  # ไม่ใช้ item_ids= ของ has_many :through เพราะ Rails จะบันทึก lot ทันทีก่อน validate
  attr_reader :selected_item_ids

  validates :name, :starts_at, :ends_at, presence: true
  validates :name, length: { maximum: 200 }
  validate :ends_after_bidding_window
  validate :starts_in_future, if: -> { new_record? || will_save_change_to_starts_at? }
  validate :auction_method_selectable, if: -> { new_record? || will_save_change_to_auction_method_id? }
  validate :room_selectable, if: -> { new_record? || will_save_change_to_room_id? }
  validate :status_transition_allowed, on: :update
  validate :schedule_locked_after_start, on: :update
  validate :items_selection_valid, unless: -> { selected_item_ids.nil? }

  after_save :sync_lots, unless: -> { selected_item_ids.nil? }
  # ตั้ง job เริ่มการประมูลไว้ที่ starts_at ทุกครั้งที่สร้างหรือเลื่อนเวลา (job เก่าที่เวลาไม่ตรงจะไม่ทำอะไร)
  after_commit :schedule_start, on: %i[create update], if: -> { scheduled? && saved_change_to_starts_at? }
  # เริ่มรับราคาแล้ว → ตั้ง job สรุปผลไว้ที่เวลาปิดรับราคา (NFR-06) job ที่หลุดมี SettleDueAuctionEventsJob กวาดซ้ำ
  after_commit :schedule_settlement, on: :update, if: -> { bidding? && saved_change_to_status? }

  scope :unfinished, -> { where(status: %w[scheduled bidding]) }
  # ถึงเวลาเริ่มแล้วแต่ยังไม่ได้เริ่ม (ให้ job กวาดซ้ำเก็บตก)
  scope :due_to_start, -> { scheduled.where(starts_at: ..Clock.now) }

  # หลัง job ปิดรับราคาที่ตั้งไว้ รอเพิ่มอีกเล็กน้อยให้เลยเส้นตายแน่ๆ ก่อนสรุป (เส้นตายเองยังนับว่ายื่นทัน)
  SETTLEMENT_DELAY = 1.second

  # เปิดรับราคาอยู่และเลยเวลาปิดรับราคาแล้ว (ต้องดูระยะเวลาจากวิธีประมูลของแต่ละ event จึงกรองในโค้ด)
  def self.due_to_settle
    bidding.includes(:auction_method).select { |event| Clock.passed?(event.bidding_ends_at) }
  end

  def selected_item_ids=(ids)
    @selected_item_ids = Array(ids).compact_blank.map(&:to_i).uniq
  end

  # id ของสินค้าที่อยู่ใน event นี้ (ไม่นับ lot ที่ถูกยกเลิก) ใช้ติ๊กช่องในฟอร์ม
  def current_item_ids
    selected_item_ids || lots.reject(&:cancelled?).map(&:item_id)
  end

  # สินค้าที่เลือกใส่ event นี้ได้ (EVT-04): พร้อมขาย ไม่เก็บถาวร ไม่อยู่ใน event อื่นที่ยังไม่จบ
  # รวมสินค้าที่อยู่ใน event นี้อยู่แล้วด้วย เพื่อให้แก้ไขโดยไม่หลุดหายจากรายการ
  def selectable_items
    busy = Lot.pending.where.not(auction_event_id: id).select(:item_id)
    available = Item.active.available.where.not(id: busy)
    Item.where(id: available).or(Item.where(id: lots.pending.select(:item_id))).order(:name)
  end

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
  # ล็อกแถวไว้ กันชนกับ start! ที่อาจรันพร้อมกันพอดีตอนถึงเวลาเริ่ม
  def cancel!
    with_lock do
      transition_to!(:cancelled, cancelled_at: Clock.now)
      lots.pending.find_each { |lot| lot.update!(status: :cancelled) }
    end
  end

  # EVT-07: เมื่อถึงเวลาเริ่ม สถานะเป็น "เปิดรับราคา" และสินค้าทุกชิ้นเป็น "อยู่ระหว่างการประมูล" พร้อมกัน (BID-16)
  # รันซ้ำได้ผลเดิม: ยังไม่ถึงเวลา / เริ่มไปแล้ว / ถูกยกเลิก → ไม่ทำอะไร คืน false (เริ่มสำเร็จคืน true)
  # สินค้าที่ไม่อยู่ในสถานะ "พร้อมขาย" แล้ว (เช่น ถูกเก็บถาวรหลังใส่ event) ถูกถอนออกจากรอบนี้ (lot = cancelled)
  # เรียกจาก StartAuctionEventJob (ตั้งเวลาไว้ที่ starts_at) และ StartDueAuctionEventsJob (กวาดซ้ำ)
  def start!
    started = false
    with_lock do
      next unless scheduled? && Clock.reached?(starts_at)

      lots.pending.includes(:item).find_each do |lot|
        if lot.item.available? && !lot.item.archived?
          lot.item.update!(status: :in_auction)
        else
          lot.update!(status: :cancelled)
        end
      end
      transition_to!(:bidding)
      started = true
    end
    started
  end

  # BID-06..10, BID-14: เมื่อเลยเวลาปิดรับราคา คัดผู้ชนะทุก lot แล้วสรุปผล event ใน transaction เดียว
  #   - ราคาสูงสุดชนะ เท่ากันให้ผู้ยื่นก่อน (BID-06, BID-07) จ่ายตามราคาที่ตนยื่น
  #   - ต้องไม่ต่ำกว่าราคาขั้นต่ำ (BID-08): ถึง → lot ขายได้ สินค้า "ขายได้แล้ว" (BID-10)
  #     ไม่มีผู้ยื่น/ต่ำกว่าขั้นต่ำ → lot ไม่ขาย สินค้ากลับเป็น "พร้อมขาย" นำไปใส่ event ใหม่ได้ (BID-09, ITEM-11)
  #   - ราคาของผู้ที่ถูกระงับภายหลังนับตามปกติ (BID-17, SUSP-04) · การระงับไม่เปลี่ยนผลที่สรุปแล้ว (SUSP-05)
  # รันซ้ำได้ผลเดิม (BID-14): ยังไม่ถึงเวลา / สรุปไปแล้ว / ยกเลิก → ไม่ทำอะไร คืน false (สรุปสำเร็จคืน true)
  # ล็อกแถว event ไว้ ราคาที่ยื่นพร้อมกันพอดีกับการสรุปจึงเรียงคิวกัน (PlaceBid ล็อกแถวเดียวกัน)
  def settle!
    settled = false
    with_lock do
      next unless bidding? && Clock.passed?(bidding_ends_at)

      lots.pending.includes(:item).find_each { |lot| settle_lot(lot) }
      transition_to!(:settled, settled_at: Clock.now)
      settled = true
    end
    settled
  end

  private
    def schedule_start
      StartAuctionEventJob.set(wait_until: starts_at).perform_later(id)
    end

    def schedule_settlement
      SettleAuctionEventJob.set(wait_until: bidding_ends_at + SETTLEMENT_DELAY).perform_later(id)
    end

    def settle_lot(lot)
      winner = lot.bids.for_settlement.first
      if winner && winner.amount >= lot.item.reserve_price
        lot.update!(status: :sold, winning_price: winner.amount, winning_bid: winner)
        lot.item.update!(status: :sold)
      else
        lot.update!(status: :unsold)
        lot.item.update!(status: :available)
      end
    end

    # EVT-05: เวลาสิ้นสุด ≥ เวลาเริ่ม + ระยะเวลายื่นราคา
    def ends_after_bidding_window
      return if starts_at.blank? || ends_at.blank? || auction_method.blank?
      return if ends_at >= bidding_ends_at

      errors.add(:ends_at, :before_bidding_window,
        message: "ต้องไม่เร็วกว่าเวลาเริ่ม + #{auction_method.bidding_seconds} วินาที")
    end

    def starts_in_future
      return if starts_at.blank? || starts_at > Clock.now

      errors.add(:starts_at, :in_past, message: "ต้องเป็นเวลาในอนาคต")
    end

    # METH-06: วิธีที่ปิดใช้งาน (หรือยังไม่มีกติกาจริง) เลือกตอนสร้าง/เปลี่ยนไม่ได้ · event เดิมไม่กระทบ
    def auction_method_selectable
      return if auction_method.blank? || AuctionMethod.selectable.exists?(auction_method.id)

      errors.add(:auction_method, :not_selectable, message: "ถูกปิดใช้งานหรือยังไม่รองรับ")
    end

    # ROOM-05: ห้องที่เก็บถาวรแล้วเลือกใส่ event ใหม่ไม่ได้
    def room_selectable
      return if room.blank? || !room.archived?

      errors.add(:room, :archived, message: "ถูกเก็บถาวรแล้ว")
    end

    # EVT-02/03/04/08 ของสินค้าที่เลือก
    def items_selection_valid
      if selected_item_ids.empty?
        errors.add(:selected_item_ids, :blank, message: "ต้องเลือกสินค้าอย่างน้อย 1 ชิ้น")
        return
      end

      if persisted? && status_in_database != "scheduled" && selected_item_ids.sort != lots.map(&:item_id).sort
        errors.add(:selected_item_ids, :locked_after_start, message: "แก้สินค้าไม่ได้เมื่อการประมูลเริ่มแล้ว")
        return
      end

      if room && selected_item_ids.size > room.max_items
        errors.add(:selected_item_ids, :too_many,
          message: "เลือกได้ไม่เกิน #{room.max_items} ชิ้นตามที่ห้องรองรับ (เลือก #{selected_item_ids.size} ชิ้น)")
      end

      allowed = selectable_items.where(id: selected_item_ids).pluck(:id)
      rejected = Item.where(id: selected_item_ids - allowed).pluck(:name)
      if (selected_item_ids - allowed).any?
        errors.add(:selected_item_ids, :not_selectable,
          message: "เลือกไม่ได้: #{rejected.presence&.join(', ') || 'ไม่พบสินค้า'} (ต้องพร้อมขายและไม่อยู่ในการประมูลอื่น)")
      end
    end

    # สร้าง lot ของสินค้าที่เพิ่ม และลบ lot ของสินค้าที่เอาออก (ทำได้เฉพาะก่อนเริ่ม ตรวจไว้ใน items_selection_valid)
    def sync_lots
      current = lots.pending.to_a
      current.reject { |lot| selected_item_ids.include?(lot.item_id) }.each { |lot| remove_lot(lot) }
      (selected_item_ids - current.map(&:item_id)).each { |item_id| add_lot(item_id) }
      lots.reset
      @selected_item_ids = nil
    end

    # เอาสินค้าออกจาก event: lot ที่มีประวัติการเข้าร่วมลบไม่ได้ (NFR-19, FK restrict ของ participations)
    # จึงยกเลิกการเข้าร่วมที่ยังค้างอยู่ (คืนที่นั่ง) แล้วตั้ง lot เป็น cancelled เก็บแถวเป็นประวัติ · ไม่มีประวัติลบได้ตามปกติ
    def remove_lot(lot)
      return lot.destroy! unless Participation.exists?(lot_id: lot.id)

      Participation.active.where(lot_id: lot.id).update_all(cancelled_at: Time.current, updated_at: Time.current)
      lot.update!(status: :cancelled)
    end

    # เพิ่มสินค้า: ถ้าเคยเอาสินค้านี้ออกจาก event นี้ (lot เป็น cancelled, unique index ของ event+สินค้า) ใช้ lot เดิมกลับมา
    # ผู้ที่เคยเข้าร่วมถูกยกเลิกไปแล้วตอนเอาออก ต้องกดเข้าร่วมใหม่
    def add_lot(item_id)
      revived = lots.cancelled.find_by(item_id: item_id)
      revived ? revived.update!(status: :pending) : lots.create!(item_id: item_id)
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
