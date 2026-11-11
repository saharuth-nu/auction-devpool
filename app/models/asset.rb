# ทรัพย์สินหนึ่งรายการในรอบส่งตรวจ (task #33/#34 · QUAL-02, QUAL-03, QUAL-03a, QUAL-13)
# ไม่มีไฟล์แนบ (QUAL-03) · บันทึกแล้วแก้ไม่ได้ (รอบเก่าไม่ถูกแก้)
class Asset < ApplicationRecord
  NAME_MAX = 100
  VALUE_MAX = BigDecimal("1_000_000_000_000")
  # ตัวเลขบวก ทศนิยมไม่เกิน 2 ตำแหน่ง (ตรวจจากค่าที่กรอก ก่อน column ปัดทศนิยมให้เงียบๆ)
  VALUE_FORMAT = /\A\d+(\.\d{1,2})?\z/

  belongs_to :qualification_submission

  normalizes :name, with: ->(v) { v.strip }

  validates :name, presence: true, length: { maximum: NAME_MAX }
  validate :value_rules

  # รับค่าที่ผู้ใช้พิมพ์คั่นหลักพัน เช่น "1,500,000.50"
  def value=(raw)
    super(raw.is_a?(String) ? raw.delete(", ") : raw)
  end

  def readonly?
    persisted? || super
  end

  private

  def value_rules
    raw = value_before_type_cast
    if raw.blank?
      errors.add(:value, :blank)
    elsif raw.is_a?(String) && !raw.match?(VALUE_FORMAT)
      errors.add(:value, "ต้องเป็นตัวเลขมากกว่า 0 ทศนิยมไม่เกิน 2 ตำแหน่ง")
    elsif value.nil? || value <= 0
      errors.add(:value, "ต้องมากกว่า 0")
    elsif value.round(2) != BigDecimal(raw.to_s)
      errors.add(:value, "ทศนิยมไม่เกิน 2 ตำแหน่ง")
    elsif value > VALUE_MAX
      errors.add(:value, "ไม่เกิน 1,000,000,000,000 บาทต่อรายการ")
    end
  rescue ArgumentError
    errors.add(:value, "ต้องเป็นตัวเลข")
  end
end
