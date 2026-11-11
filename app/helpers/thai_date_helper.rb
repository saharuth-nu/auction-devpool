# แสดงวันที่/เวลาแบบไทย (เดือนย่อ + ปี พ.ศ.) ใช้ได้ทุก view
#   thai_date(Date.new(2026, 11, 15))                     # => "15 พ.ย. 2569"
#   thai_time_range(starts_at, ends_at)                   # => "10:00–12:00 น."
module ThaiDateHelper
  THAI_MONTHS = %w[ม.ค. ก.พ. มี.ค. เม.ย. พ.ค. มิ.ย. ก.ค. ส.ค. ก.ย. ต.ค. พ.ย. ธ.ค.].freeze
  BUDDHIST_ERA_OFFSET = 543

  def thai_date(date)
    return "" if date.nil?

    "#{date.day} #{THAI_MONTHS[date.month - 1]} #{date.year + BUDDHIST_ERA_OFFSET}"
  end

  def thai_time_range(starts_at, ends_at)
    "#{starts_at.strftime('%H:%M')}–#{ends_at.strftime('%H:%M')} น."
  end
end
