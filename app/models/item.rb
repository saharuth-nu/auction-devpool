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

  validates :name, presence: true
  validates :starting_price, :reserve_price, presence: true
  validates :starting_price, :reserve_price, numericality: { greater_than: 0 }, allow_nil: true
  validates :reserve_price, comparison: { greater_than_or_equal_to: :starting_price },
    if: -> { starting_price.present? && reserve_price.present? }
  validate :prices_locked_during_auction
  validate :images_acceptable

  before_destroy :prevent_destroy_during_auction

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
