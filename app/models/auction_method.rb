# วิธีการประมูล (METH-*) ผูกกับ event
# ระยะเวลายื่นราคาอยู่ที่ bidding_seconds ที่เดียว ห้ามฝังตัวเลข 30 ในโค้ดที่อื่น (METH-07)
class AuctionMethod < ApplicationRecord
  # รหัสที่มีกติกาเขียนไว้จริงแล้ว วิธีใหม่ (english, dutch) เพิ่มรหัสที่นี่เมื่อเขียนกติกาเสร็จ (METH-04/05)
  IMPLEMENTED_CODES = %w[first_price].freeze

  has_many :auction_events, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true,
    format: { with: /\A[a-z][a-z0-9_]*\z/, message: "ใช้ได้เฉพาะ a-z, 0-9 และ _ (ขึ้นต้นด้วยตัวอักษร)" }
  validates :name, presence: true
  validates :bidding_seconds, numericality: { only_integer: true, greater_than: 0 }

  scope :enabled, -> { where(enabled: true) }
  # ตัวเลือกตอนสร้าง event ใหม่: เปิดใช้งานและมีกติกาจริง (METH-06) · event เดิมไม่กระทบ
  scope :selectable, -> { enabled.where(code: IMPLEMENTED_CODES) }

  def self.first_price
    find_by!(code: "first_price")
  end

  def bidding_duration
    bidding_seconds.seconds
  end

  def implemented?
    IMPLEMENTED_CODES.include?(code)
  end

  def enable!
    update!(enabled: true)
  end

  def disable!
    update!(enabled: false)
  end
end
