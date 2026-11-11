# ตัวตรวจว่า view และ CSS ทำตามมาตรฐาน UI (DESIGN.md) · ใช้ใน test/design/design_lint_test.rb
#
# ตรวจ 3 เรื่องที่ issue #74 ต้องปิด:
#   NFR-10  ใช้ component และ token: ไม่มีสี hex / font-size px ฝัง, ไม่เขียนปุ่ม/ช่องกรอก/ตารางเอง
#   NFR-11  ทุกช่องกรอกมี label และ error ใต้ช่อง: ต้องผ่าน f.ui_field (ที่บังคับ label ให้)
#   NFR-13  การกระทำที่ย้อนกลับไม่ได้ต้องมีขั้นยืนยัน: ปุ่มส่งฟอร์มที่ชื่อ ลบ/อนุมัติ/ไม่ผ่าน/ยกเลิก/ปิดใช้งาน/ระงับ ต้องผ่าน ui_confirm_button
#
# เป็นตาข่ายกันพลาด ไม่ใช่ตัวตัดสินทั้งหมด: กฎจริงอยู่ที่ DESIGN.md หัวข้อ 4
module DesignLint
  Violation = Struct.new(:file, :line, :rule, :excerpt, :fix) do
    def to_s = "#{file}:#{line} [#{rule}] #{excerpt.strip[0, 90]}\n    → #{fix}"
  end

  COLOR_PROPERTY = /(?:color|background(?:-color)?|border(?:-color)?|fill|stroke)\s*[:=]\s*["']?#[0-9a-fA-F]{3,8}\b/
  INLINE_STYLE_LOOK = /style\s*=\s*["'][^"']*(?:color|font|background|list-style|padding|margin|display|grid|border|gap|align)[^"']*["']/i
  RAW_TAG = /<(?:input|select|textarea|button)\b[^>]*>/i
  FIELD_METHODS = %w[text_field text_area password_field email_field number_field telephone_field url_field search_field
                     date_field datetime_local_field time_field file_field check_box radio_button collection_select
                     select submit button].join("|")
  RAW_FIELD_CALL = /(?:\b(?:f|form)\.(?:#{FIELD_METHODS})\b)|(?:\b(?:text_field|text_area|password_field|select|check_box|file_field|submit|button)_tag\b)|(?<!\w)(?:form_for|form_tag|form_with|button_to)\b/
  RAW_TABLE = /<table\b(?![^>]*ui-table)/i

  # ชื่อปุ่มที่บอกว่าย้อนกลับไม่ได้ (NFR-13) และชื่อที่ไม่นับ (ย้อนกลับได้)
  # (?<!เ) กัน "เปิดใช้งาน" / "เปิดประมูล" ที่มี "ปิดใช้งาน" / "ปิดประมูล" อยู่ในคำ
  IRREVERSIBLE_LABEL = /ลบ|อนุมัติ|ไม่ผ่าน|ปฏิเสธ|ยกเลิก|(?<!เ)ปิดใช้งาน|ระงับ|(?<!เ)ปิดประมูล/
  REVERSIBLE_LABEL = /\A(?:ยกเลิก(?:การ)?ระงับ|ออกจากระบบ)/
  ACTION_BUTTON = /(?<!\w)(?:ui_button_to|button_to)\s*\(?\s*["']([^"']+)["']/

  CSS_HEX = /#[0-9a-fA-F]{3,8}\b/
  CSS_PX_FONT = /font-size\s*:\s*[\d.]+px|\bfont\s*:\s*(?:[\w-]+\s+)*[\d.]+px/

  module_function

  def scan(root = Rails.root)
    views = Dir[root.join("app/views/**/*.erb")].flat_map { |path| check_view(relative(root, path), File.read(path)) }
    css = Dir[root.join("app/assets/stylesheets/*.css")].reject { |path| File.basename(path) == "tokens.css" }
                                                         .flat_map { |path| check_css(relative(root, path), File.read(path)) }
    views + css
  end

  def check_view(file, source)
    code = blank_out(source, /<%#.*?%>/m) # คอมเมนต์ ERB ไม่ตรวจ
    found = []
    each_match(code, COLOR_PROPERTY) { |m, line| found << violation(file, line, "hex-in-view", m, "ใช้ token สี เช่น var(--color-primary-600) ใน CSS (DESIGN.md หัวข้อ 1)") }
    each_match(code, INLINE_STYLE_LOOK) { |m, line| found << violation(file, line, "inline-style", m, "อย่าตั้งสี/ฟอนต์/ระยะห่าง/layout ใน style= ใช้ class ui-* หรือเพิ่ม class ใน CSS") }
    each_match(code, RAW_TAG) do |m, line|
      next if m =~ /\btype\s*=\s*["']hidden["']/i

      found << violation(file, line, "raw-control", m, "ใช้ ui_button / f.ui_field (DESIGN.md หัวข้อ 3) เพื่อให้มี label และ error ใต้ช่อง")
    end
    each_match(code, RAW_FIELD_CALL) { |m, line| found << violation(file, line, "raw-form-helper", m, "ใช้ ui_form_with, f.ui_field, f.ui_submit, ui_button_to แทน") }
    each_match(code, RAW_TABLE) { |m, line| found << violation(file, line, "raw-table", m, '<table class="ui-table"> ภายใน ui_table_card') }
    found + irreversible_without_confirm(file, code)
  end

  def check_css(file, source)
    code = blank_out(source, %r{/\*.*?\*/}m)
    found = []
    each_match(code, CSS_HEX) { |m, line| found << violation(file, line, "hex-in-css", m, "ใช้ var(--color-*) จาก tokens.css (เพิ่ม token ที่ tokens.css ถ้าจำเป็น)") }
    each_match(code, CSS_PX_FONT) { |m, line| found << violation(file, line, "px-font-size", m, "ใช้ var(--text-*) จาก tokens.css (DESIGN.md หัวข้อ 2)") }
    found
  end

  # ปุ่มส่งฟอร์มที่ชื่อบอกว่าย้อนกลับไม่ได้ แต่ไม่ได้ผ่านขั้นยืนยัน
  def irreversible_without_confirm(file, code)
    tags = []
    code.scan(/<%.*?%>/m) { tags << [ Regexp.last_match.begin(0), Regexp.last_match[0] ] }
    tags.filter_map do |offset, tag|
      label = tag[ACTION_BUTTON, 1]
      next if label.nil? || label !~ IRREVERSIBLE_LABEL || label =~ REVERSIBLE_LABEL
      next if tag.include?("confirm") || tag =~ /reversible:\s*true/

      violation(file, code[0, offset].count("\n") + 1, "no-confirm", tag.lines.first,
                "การกระทำ “#{label}” ย้อนกลับไม่ได้ ใช้ ui_confirm_button พร้อม title และ message (NFR-13) " \
                "ถ้าย้อนกลับได้จริงใส่ data: { reversible: true }")
    end
  end

  def each_match(code, regex)
    code.scan(regex) do
      match = Regexp.last_match
      yield match[0], code[0, match.begin(0)].count("\n") + 1
    end
  end

  # แทนส่วนที่ไม่ตรวจด้วยช่องว่าง โดยคงจำนวนบรรทัดไว้ให้เลขบรรทัดถูก
  def blank_out(source, regex)
    source.gsub(regex) { |m| m.gsub(/[^\n]/, " ") }
  end

  def relative(root, path) = Pathname(path).relative_path_from(root).to_s

  def violation(file, line, rule, excerpt, fix) = Violation.new(file, line, rule, excerpt, fix)
end
