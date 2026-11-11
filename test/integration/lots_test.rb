require "test_helper"

# USR-04 (หน้ารายละเอียดสินค้า: รูปหลายภาพ รายละเอียด ราคาเริ่มต้น เวลาประมูล ห้อง)
# USR-05 (ปุ่มเข้าร่วมประมูลก่อนถึงเวลา) และการกันข้อมูลลับ (BID-18)
class LotsTest < ActionDispatch::IntegrationTest
  setup do
    @lot = lots(:upcoming_necklace)
    @item = items(:necklace) # ราคาเริ่มต้น 20,000 reserve 25,000
    @event = auction_events(:upcoming)
  end

  def page = Nokogiri::HTML(response.body)

  def show_lot(lot = @lot)
    sign_in create_approved_bidder
    get lot_path(lot)
  end

  def attach_photos(item, count)
    count.times do
      item.images.attach(io: File.open(file_fixture("photo.png")), filename: "photo.png", content_type: "image/png")
    end
  end

  def dd_for(label)
    page.css(".ui-dl dt").find { |dt| dt.text == label }.next_element.text
  end

  # ---------- USR-04: ข้อมูลบนหน้า ----------

  test "USR-04 แสดงชื่อ รายละเอียด ราคาเริ่มต้น เวลาประมูล ห้อง และวิธีประมูล" do
    @item.update!(description: "สร้อยทองคำแท้ น้ำหนัก 1 บาท\nสภาพดีมาก")
    show_lot
    assert_response :success
    assert_equal "สร้อยคอทองคำ", page.at_css("h1").text
    assert_equal "20,000 บาท", dd_for("ราคาเริ่มต้น")
    assert_equal ApplicationController.helpers.display_time(@event.starts_at), dd_for("เวลาประมูล")
    assert_equal "ห้องใหญ่", dd_for("ห้อง")
    assert_equal "ประมูลเครื่องประดับ", dd_for("การประมูล")
    assert_equal "ประมูลราคาปิด (First-Price Sealed)", dd_for("วิธีประมูล")
    assert_includes page.text, "สร้อยทองคำแท้ น้ำหนัก 1 บาท"
    assert_includes page.text, "สภาพดีมาก"
  end

  test "METH-07 ระยะเวลายื่นราคามาจากวิธีประมูล ไม่ฝังตัวเลข" do
    show_lot
    assert_equal "30 วินาทีหลังเริ่มประมูล", dd_for("ยื่นราคาได้ภายใน")

    @event.auction_method.update!(bidding_seconds: 45)
    get lot_path(@lot)
    assert_equal "45 วินาทีหลังเริ่มประมูล", dd_for("ยื่นราคาได้ภายใน")
  end

  test "NFR-11 ไม่มีรายละเอียดแสดงข้อความ ยังไม่มีรายละเอียด" do
    # ITEM-13 บังคับกรอกรายละเอียดแล้ว แต่ข้อมูลเก่าที่ว่างอยู่ต้องยังแสดงข้อความสำรอง (จำลองด้วยการเขียนตรง ข้าม validation)
    @item.update_column(:description, nil)
    show_lot
    assert_includes page.text, "ยังไม่มีรายละเอียด"
  end

  test "USR-04 แสดงรูปทุกภาพ ภาพแรกเด่น พร้อม alt และโหลดภาพที่เหลือแบบ lazy" do
    attach_photos(@item, 3)
    show_lot
    items = page.css("ul.ui-gallery > li")
    assert_equal 3, items.size
    assert_includes items.first["class"].split, "ui-gallery__item--main"
    images = page.css("img.ui-gallery__image")
    assert_equal [ "สร้อยคอทองคำ รูปที่ 1", "สร้อยคอทองคำ รูปที่ 2", "สร้อยคอทองคำ รูปที่ 3" ], images.map { |i| i["alt"] }
    assert_equal %w[eager lazy lazy], images.map { |i| i["loading"] }
  end

  test "NFR-11 ไม่มีรูปแสดงกรอบ ไม่มีรูป ที่อ่านออกเสียงได้" do
    show_lot
    assert_nil page.at_css("img.ui-gallery__image")
    empty = page.at_css(".ui-gallery__empty")
    assert_equal "ไม่มีรูป", empty.text
    assert_equal "ไม่มีรูปสินค้า สร้อยคอทองคำ", empty["aria-label"]
  end

  test "ข้อความจากข้อมูลสินค้าถูก escape" do
    @item.update!(name: "<script>alert(1)</script>", description: "<script>x()</script>สวัสดี")
    show_lot
    assert_not_includes response.body, "<script>alert(1)"
    assert_not_includes response.body, "<script>x()"
    assert_includes page.text, "สวัสดี"
  end

  # ---------- BID-18 ----------

  test "BID-18 ไม่รั่วราคาขั้นต่ำ (reserve) และไม่บอกว่ามี reserve" do
    show_lot
    assert_not_includes response.body, ApplicationController.helpers.baht(@item.reserve_price)
    assert_not_includes response.body, "25000"
    assert_not_includes page.text.downcase, "reserve"
    assert_not_includes page.text, "ราคาขั้นต่ำ"
  end

  # ---------- USR-05 + NFR-03: ปุ่มเข้าร่วมก่อนถึงเวลา ตัดสินด้วยเวลาของ server ----------

  test "USR-05 ก่อนถึงเวลาเริ่ม มีปุ่มเข้าร่วมประมูล" do
    travel_to @event.starts_at - 1.second do
      show_lot
      button = page.css("button").find { |b| b.text == "เข้าร่วมประมูล" }
      assert button, "ต้องมีปุ่มเข้าร่วมประมูล"
      assert_not button["disabled"], "ปุ่มเข้าร่วมต้องกดได้ (USR-05)"
      assert_equal "รอเริ่ม", page.at_css(".ui-page-header .ui-badge").text
      assert_nil page.at_css(".ui-alert")
    end
  end

  test "USR-05 ถึงเวลาเริ่มพอดี ปุ่มหายและบอกว่าเริ่มแล้ว" do
    travel_to @event.starts_at do
      show_lot
      assert_nil page.css("button").find { |b| b.text == "เข้าร่วมประมูล" }
      assert_equal "การประมูลนี้เริ่มแล้ว เข้าห้องประมูลเพื่อเข้าร่วมได้จนปิดรับราคา", page.at_css(".ui-alert").text.strip
      assert_equal "กำลังประมูล", page.at_css(".ui-page-header .ui-badge").text
      assert page.at_css("a[href='#{auction_event_room_path(@event)}']"), "เริ่มแล้ว: ไปห้องประมูลเพื่อเข้าร่วมได้ (USR-10)"
    end
  end

  test "NFR-03 เลยเวลารับราคา (เริ่ม + ระยะเวลาของวิธีประมูล) แสดงปิดรับราคา" do
    travel_to @event.bidding_ends_at do # ครบพอดียังรับราคาอยู่
      show_lot
      assert_equal "การประมูลนี้เริ่มแล้ว เข้าห้องประมูลเพื่อเข้าร่วมได้จนปิดรับราคา", page.at_css(".ui-alert").text.strip
    end
    travel_to @event.bidding_ends_at + 1.second do
      show_lot
      assert_equal "ปิดรับราคาแล้ว กำลังสรุปผล", page.at_css(".ui-alert").text.strip
      assert_equal "ปิดประมูล", page.at_css(".ui-page-header .ui-badge").text
    end
  end

  # ---------- USR-03: เปิดดูได้เฉพาะ lot ที่หน้าแรกแสดง ----------

  test "lot ใน event ที่สรุปผลแล้วเปิดดูไม่ได้ (404)" do
    sign_in create_approved_bidder
    get lot_path(lots(:finished_lamp))
    assert_response :not_found
  end

  test "lot ใน event ที่ยกเลิกเปิดดูไม่ได้ (404)" do
    @event.cancel!
    show_lot
    assert_response :not_found
  end

  test "lot ที่ไม่ใช่ pending เปิดดูไม่ได้ (404)" do
    @lot.update!(status: :unsold)
    show_lot
    assert_response :not_found
  end

  test "สินค้าที่เก็บถาวรเปิดดูไม่ได้ (404)" do
    @item.archive!
    show_lot
    assert_response :not_found
  end

  test "id ที่ไม่มีอยู่ได้ 404" do
    sign_in create_approved_bidder
    get lot_path(0)
    assert_response :not_found
  end

  # ---------- สิทธิ์ ----------

  test "NFR-08 ยังไม่ login ถูกส่งไปหน้า login" do
    get lot_path(@lot)
    assert_redirected_to login_path
  end

  test "QUAL-05 ผู้ใช้ที่ยังไม่ผ่านการตรวจคุณสมบัติถูกส่งไปหน้าสถานะ" do
    sign_in create_bidder
    get lot_path(@lot)
    assert_redirected_to qualification_path
  end

  test "NFR-08 admin เปิดหน้าของผู้ใช้ไม่ได้ (403)" do
    sign_in create_admin
    get lot_path(@lot)
    assert_response :forbidden
  end
end
