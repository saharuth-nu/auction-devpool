# ผู้ใช้ระบบ: admin และผู้ประมูล (bidder) อยู่ตารางเดียว แยกด้วย role
# requirements: AUTH-04, AUTH-05, AUTH-06, AUTH-08, AUTH-15 (ดู requirements/01-accounts.md)
class User < ApplicationRecord
  PASSWORD_MIN = 8
  PASSWORD_MAX_BYTES = 72 # bcrypt ตัดรหัสผ่านที่ยาวกว่า 72 ไบต์ ต้องตรวจเป็นไบต์ ไม่ใช่จำนวนตัวอักษร

  has_secure_password

  enum :role, { admin: "admin", bidder: "bidder" }, default: :bidder

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

  private

  def password_within_bcrypt_limit
    return if password.blank? || password.bytesize <= PASSWORD_MAX_BYTES

    errors.add(:password, "ยาวเกินไป (ไม่เกิน #{PASSWORD_MAX_BYTES} ไบต์)")
  end
end
