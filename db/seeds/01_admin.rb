# admin คนแรก (AUTH-09): ไม่มีหน้า register ของ admin จึงสร้างจาก seed
# - ตั้งค่าผ่าน ENV: ADMIN_USERNAME (ค่าเริ่มต้น admin) และ ADMIN_PASSWORD
# - production ต้องตั้ง ADMIN_PASSWORD เอง (ไม่มีรหัสผ่านเริ่มต้นใน repo)
# - development/test ถ้าไม่ตั้ง จะสุ่มรหัสผ่านและพิมพ์ให้ดูครั้งเดียว
# - สร้างเฉพาะเมื่อยังไม่มี admin เลย (รันซ้ำไม่เพิ่มหรือเปลี่ยนรหัสผ่านของ admin เดิม)
unless User.admin.exists?
  username = ENV.fetch("ADMIN_USERNAME", "admin")
  password = ENV["ADMIN_PASSWORD"].presence
  generated = password.nil?

  if generated
    raise "ต้องตั้ง ADMIN_PASSWORD ก่อนรัน db:seed ใน production" if Rails.env.production?

    password = User.generate_temporary_password
  end

  User.create!(username: username, password: password, password_confirmation: password, role: :admin)

  unless Rails.env.test?
    puts "สร้าง admin คนแรกแล้ว: username=#{username}"
    puts "รหัสผ่าน (แสดงครั้งเดียว): #{password}" if generated
  end
end
