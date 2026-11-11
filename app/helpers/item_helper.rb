# การ์ดสินค้าในรายการ (USR-02): รูป, ชื่อ, เวลาประมูล, ราคาเริ่มต้น
#
#   item_card(entry.item, starts_at: entry.starts_at)                 # การ์ดเฉยๆ
#   item_card(entry.item, starts_at: entry.starts_at, url: item_path(entry.item))  # คลิกทั้งการ์ดไปหน้ารายละเอียด (USR-04)
#
# ป้ายสถานะดูจากเวลา: ยังไม่ถึงเวลาเริ่ม = รอเริ่ม, ถึงแล้ว = กำลังประมูล (ใช้ Clock ตัดสินที่ server, NFR-03)
# รูปใช้รูปแรกของสินค้า ไม่มีรูปแสดงกรอบ "ไม่มีรูป"
# หมายเหตุ: ใช้รูปต้นฉบับ (ไม่ได้ย่อด้วย variant เพราะต้องมี libvips บนเครื่อง) ถ้ารายการยาวควรย่อรูปภายหลัง
module ItemHelper
  def item_card(item, starts_at:, url: nil)
    started = Clock.reached?(starts_at)
    content_tag(:article, class: "ui-item-card") do
      safe_join([
        item_card_image(item),
        content_tag(:div, class: "ui-item-card__body") do
          safe_join([
            status_badge(:auction, started ? :active : :scheduled),
            content_tag(:h3, item_card_name(item, url), class: "ui-item-card__name"),
            content_tag(:dl, class: "ui-item-card__meta") do
              safe_join([
                content_tag(:dt, "เวลาประมูล"), content_tag(:dd, display_time(starts_at)),
                content_tag(:dt, "ราคาเริ่มต้น"), content_tag(:dd, baht(item.starting_price), class: "ui-item-card__price")
              ])
            end
          ])
        end
      ])
    end
  end

  private

  def item_card_name(item, url)
    url ? link_to(item.name, url, class: "ui-item-card__link") : item.name
  end

  def item_card_image(item)
    if item.images.attached?
      image_tag(item.images.first, alt: item.name, loading: "lazy", decoding: "async", class: "ui-item-card__image")
    else
      content_tag(:div, "ไม่มีรูป", class: "ui-item-card__image ui-item-card__image--empty",
                                    role: "img", "aria-label": "ไม่มีรูปสินค้า #{item.name}")
    end
  end
end
