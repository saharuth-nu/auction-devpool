# สินค้าประมูล (ITEM-*)
# สถานะ: รออนุมัติ → พร้อมขาย → อยู่ระหว่างการประมูล → ขายได้แล้ว (ITEM-02)
class Item < ApplicationRecord
  include Archivable

  class InvalidTransition < StandardError; end

  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_IMAGE_SIZE = 5.megabytes
  MAX_IMAGES = 10
  LOCKED_PRICE_ATTRIBUTES = %i[starting_price reserve_price].freeze

  enum :status, {
    awaiting_approval: "awaiting_approval",
    available: "available",
    in_auction: "in_auction",
    sold: "sold"
  }

  belongs_to :approved_by, class_name: "User", optional: true
  has_many_attached :images
  has_many :lots, dependent: :restrict_with_error

  # ITEM-13: ชื่อและรายละเอียดบังคับทั้งคู่ (รายละเอียดแสดงในหน้ารายละเอียดสินค้า USR-04)
  validates :name, presence: true
  validates :description, presence: { message: "ต้องกรอก" }
  validates :starting_price, :reserve_price, presence: true
  validates :starting_price, :reserve_price, numericality: { greater_than: 0 }, allow_nil: true
  validates :reserve_price, comparison: { greater_than_or_equal_to: :starting_price },
    if: -> { starting_price.present? && reserve_price.present? }
  validate :prices_locked_during_auction
  validate :images_acceptable

  # prepend: ให้ข้อความ "อยู่ระหว่างการประมูล" (ITEM-09) ขึ้นก่อนข้อห้ามเพราะมี lot (NFR-19) ของ has_many :lots
  before_destroy :prevent_destroy_during_auction, prepend: true

  # ค่าว่างหรือสถานะที่ไม่รู้จัก → ทั้งหมด (ITEM-03)
  scope :filter_by_status, ->(status) { statuses.key?(status.to_s) ? where(status: status) : all }

  # รออนุมัติ → พร้อมขาย (ITEM-04)
  def approve!(by:)
    raise InvalidTransition, "อนุมัติได้เฉพาะสินค้าที่รออนุมัติ" unless awaiting_approval?
    raise InvalidTransition, "ผู้อนุมัติต้องเป็น admin" unless by&.admin?

    update!(status: :available, approved_at: Time.current, approved_by: by)
  end

  def archive!
    raise InvalidTransition, "เก็บถาวรสินค้าที่อยู่ระหว่างการประมูลไม่ได้" if in_auction?

    super
  end

  # รูปที่บันทึกแล้วตามลำดับที่ admin จัด (ITEM-07) · รูปใหม่ที่ยังไม่ถูกจัดต่อท้ายตามลำดับอัปโหลด
  # หน้าที่แสดงรูปสินค้าควรใช้ตัวนี้แทน images
  def ordered_images
    rank = image_order.each_with_index.to_h
    images.attachments.select(&:persisted?).sort_by { |attachment| [ rank.fetch(attachment.id, image_order.size), attachment.id ] }
  end

  # เลื่อนรูปขึ้น (:up) หรือลง (:down) หนึ่งตำแหน่ง · ขอบบน/ล่างไม่เปลี่ยน
  def move_image!(attachment_id, direction)
    ids = ordered_images.map(&:id)
    index = ids.index(attachment_id.to_i) or raise ActiveRecord::RecordNotFound, "ไม่พบรูปนี้ในสินค้า"
    target = direction.to_s == "up" ? index - 1 : index + 1
    return false unless target.between?(0, ids.size - 1)

    ids[index], ids[target] = ids[target], ids[index]
    update!(image_order: ids)
  end

  private
    def locked_for_auction?
      status_in_database == "in_auction"
    end

    # ITEM-09: ระหว่างประมูลแก้ราคาไม่ได้ (ชื่อ/รายละเอียดแก้ได้)
    def prices_locked_during_auction
      return unless locked_for_auction?

      LOCKED_PRICE_ATTRIBUTES.each do |attribute|
        next unless will_save_change_to_attribute?(attribute)

        errors.add(attribute, :locked_during_auction, message: "แก้ไม่ได้ขณะสินค้าอยู่ระหว่างการประมูล")
      end
    end

    # ITEM-09: ระหว่างประมูลลบไม่ได้
    def prevent_destroy_during_auction
      return unless locked_for_auction?

      errors.add(:base, :locked_during_auction, message: "ลบสินค้าที่อยู่ระหว่างการประมูลไม่ได้")
      throw :abort
    end

    # ITEM-08: JPG/PNG/WebP, ไม่เกิน 5 MB ต่อรูป, ไม่เกิน 10 รูป
    def images_acceptable
      if images.size > MAX_IMAGES
        errors.add(:images, :too_many, message: "ใส่ได้ไม่เกิน #{MAX_IMAGES} รูป")
      end

      blobs = images.map(&:blob)
      unless blobs.all? { |blob| IMAGE_CONTENT_TYPES.include?(blob.content_type) }
        errors.add(:images, :invalid_content_type, message: "รับเฉพาะไฟล์ JPG, PNG หรือ WebP")
      end
      if blobs.any? { |blob| blob.byte_size > MAX_IMAGE_SIZE }
        errors.add(:images, :file_too_large, message: "แต่ละรูปต้องไม่เกิน 5 MB")
      end
    end
end
