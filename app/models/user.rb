# ผู้ใช้ระบบ: admin และผู้ประมูล (bidder) อยู่ตารางเดียว แยกด้วย role
# requirements: AUTH-04/05/06/08/12/13/14/15/18, ADM-05/06/07/08, SUSP-02 (ดู requirements/01-accounts.md)
class User < ApplicationRecord
  PASSWORD_MIN = 8
  PASSWORD_MAX_BYTES = 72 # bcrypt ตัดรหัสผ่านที่ยาวกว่า 72 ไบต์ ต้องตรวจเป็นไบต์ ไม่ใช่จำนวนตัวอักษร
  TEMPORARY_PASSWORD_LENGTH = 12

  has_secure_password
  has_many :sessions, dependent: :destroy
  belongs_to :disabled_by, class_name: "User", optional: true

  enum :role, { admin: "admin", bidder: "bidder" }, default: :bidder

  # สถานะคุณสมบัติ/เพดานราคา (QUAL), ระงับบัญชี (SUSP), ค้นหาสำหรับ admin (ADM-01)
  include Qualification, Suspension, Directory

  # ค่าที่เก็บเป็นตัวพิมพ์เล็กเสมอ: ทำให้ unique ไม่สนตัวพิมพ์ใหญ่/เล็ก (AUTH-04/05)
  normalizes :username, with: ->(v) { v.strip.downcase }
  normalizes :email, with: ->(v) { v.strip.downcase.presence }
  normalizes :fullname, with: ->(v) { v.strip.presence }

  validates :username, presence: true
  validates :username, uniqueness: true,
                       format: { with: /\A[a-z0-9_]{4,30}\z/,
                                 message: "ใช้ได้เฉพาะ a-z 0-9 และ _ ยาว 4–30 ตัวอักษร" },
                       if: -> { username.present? } # ว่างให้ error เดียว (presence) ไม่ซ้อน format

  # ผู้ประมูลต้องมี fullname และ email; admin มีเฉพาะ username/password (ADM-04)
  with_options if: :bidder? do
    validates :fullname, presence: true
    validates :email, presence: true
  end
  validates :fullname, length: { maximum: 100 }
  validates :email, length: { maximum: 254 },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "รูปแบบไม่ถูกต้อง" },
                    uniqueness: true, allow_nil: true

  validates :password, length: { minimum: PASSWORD_MIN }, allow_nil: true
  validate :password_within_bcrypt_limit
  validates :password_confirmation, presence: true, if: -> { password.present? }

  before_destroy :prevent_admin_destroy, prepend: true

  scope :active, -> { where(suspended_at: nil, disabled_at: nil) }

  def self.generate_temporary_password
    SecureRandom.alphanumeric(TEMPORARY_PASSWORD_LENGTH)
  end

  def suspended? = suspended_at.present?
  def disabled? = disabled_at.present?

  # login ได้เมื่อไม่ถูกระงับ (SUSP-02) และไม่ถูกปิดใช้งาน (ADM-08)
  def active_for_login? = !suspended? && !disabled?

  # ---- ปิด/เปิดใช้งานบัญชี admin (ADM-05, 07, 08)
  def disable(by:, reason:)
    if by == self
      errors.add(:base, "ปิดใช้งานบัญชีของตัวเองไม่ได้")
    elsif reason.to_s.strip.blank?
      errors.add(:base, "ต้องระบุเหตุผลในการปิดใช้งาน")
    elsif admin? && User.admin.active.where.not(id: id).none?
      errors.add(:base, "ต้องมี admin ที่ใช้งานได้อย่างน้อย 1 คน")
    end
    return false if errors.any?

    transaction do
      update!(disabled_at: Time.current, disabled_reason: reason.to_s.strip, disabled_by: by)
      sessions.destroy_all # session หมดผลทันที (ADM-08)
    end
    true
  end

  def enable
    update!(disabled_at: nil, disabled_reason: nil, disabled_by: nil)
  end

  # ---- admin รีเซ็ตรหัสผ่านให้ (AUTH-12/13/14) คืนรหัสชั่วคราว (แสดงครั้งเดียว) หรือ false
  def reset_password(by:)
    if by == self
      errors.add(:base, "รีเซ็ตรหัสผ่านของตัวเองไม่ได้ (ใช้หน้าเปลี่ยนรหัสผ่านแทน)")
      return false
    end

    temporary = self.class.generate_temporary_password
    transaction do
      update!(password: temporary, password_confirmation: temporary, must_change_password: true)
      sessions.destroy_all
    end
    temporary
  end

  # ---- เปลี่ยนรหัสผ่าน (AUTH-13 บังคับเปลี่ยน / AUTH-18 เปลี่ยนทั่วไป)
  # current: ส่งรหัสเดิมเพื่อตรวจ (เปลี่ยนทั่วไป) หรือไม่ส่ง (บังคับเปลี่ยนหลังรีเซ็ต ที่ผู้ใช้ยังไม่รู้รหัสเดิมเป็นของตัวเอง)
  def change_password(new_password:, confirmation:, current: nil, keep_session: nil)
    if !current.nil? && !authenticate(current.to_s)
      errors.add(:current_password, "ไม่ถูกต้อง")
      return false
    end
    if new_password.present? && authenticate(new_password)
      errors.add(:password, "ต้องไม่ซ้ำกับรหัสผ่านเดิม")
      return false
    end

    self.password = new_password
    self.password_confirmation = confirmation
    self.must_change_password = false
    return false unless save

    sessions.where.not(id: keep_session&.id).destroy_all # session อื่นของบัญชีนี้หมดผล (AUTH-18)
    true
  end

  private

  def password_within_bcrypt_limit
    return if password.blank? || password.bytesize <= PASSWORD_MAX_BYTES

    errors.add(:password, "ยาวเกินไป (ไม่เกิน #{PASSWORD_MAX_BYTES} ไบต์)")
  end

  # ADM-06: บัญชี admin ลบไม่ได้ (ใช้ปิดใช้งานแทน) เพื่อให้ประวัติการกระทำอ้างถึงได้
  def prevent_admin_destroy
    return unless admin?

    errors.add(:base, "ลบบัญชี admin ไม่ได้ ให้ปิดใช้งานแทน")
    throw :abort
  end
end
