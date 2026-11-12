# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # ราคาลับ (NFR-04, BID-18): ราคาขั้นต่ำของสินค้า และจำนวนเงินที่ยื่น ห้ามขึ้น log ทั้งพารามิเตอร์และ inspect ของโมเดล
  # (Rails ใช้รายการนี้กับ ActiveRecord filter_attributes ด้วย จึงกรอง Item#inspect ที่ปรากฏใน log และข้อความ error)
  :reserve, :amount
]
