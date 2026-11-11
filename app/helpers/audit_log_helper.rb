# การแสดงผล audit log (NFR-18)
module AuditLogHelper
  TARGET_LABELS = { "User" => "ผู้ใช้" }.freeze

  # "ผู้ใช้ somchai" / "Item #12" (ถ้าเป้าหมายมีชื่อแสดงชื่อ ไม่มีแสดง id)
  def audit_target_label(log)
    kind = TARGET_LABELS.fetch(log.target_type, log.target_type)
    target = log.target
    name = %i[username name title].lazy.filter_map { |attr| target.try(attr) }.first if target
    name ? "#{kind} #{name}" : "#{kind} ##{log.target_id}"
  end

  # change_set { "status" => ["a", "b"], "x" => 1 } → "status: a → b · x: 1"
  def audit_change_summary(log)
    return "-" if log.change_set.blank?

    log.change_set.map { |key, value|
      text = value.is_a?(Array) && value.size == 2 ? "#{value[0].presence || '-'} → #{value[1].presence || '-'}" : value.to_s
      "#{key}: #{text}"
    }.join(" · ")
  end
end
