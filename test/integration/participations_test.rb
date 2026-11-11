require "test_helper"

# USR-05 (ปุ่มเข้าร่วม), USR-06 (ครั้งเดียว/ยกเลิกก่อนเริ่ม), USR-07 (ห้องเต็ม) ผ่านหน้าเว็บจริง
class ParticipationsTest < ActionDispatch::IntegrationTest
  setup do
    @lot = lots(:upcoming_necklace)
    @event = auction_events(:upcoming)
    @user = create_approved_bidder
    sign_in @user
  end

  def page = Nokogiri::HTML(response.body)

  def join_button = page.css("button").find { |b| b.text == "เข้าร่วมประมูล" }

  def flash_text = page.at_css(".ui-alert")&.text&.strip

  # ห้องเล็ก (จุคนเดียว) พร้อม event ที่มี 2 lot สำหรับทดสอบห้องเต็ม
  def small_room_lots(max_participants: 1)
    room = Room.create!(name: "ห้องเล็ก", max_participants:, max_items: 5)
    starts = 1.day.from_now.change(usec: 0)
    event = AuctionEvent.create!(name: "รอบเล็ก", room:, auction_method: auction_methods(:first_price), starts_at: starts, ends_at: starts + 1.hour)
    Array.new(2) do |i|
      Lot.create!(auction_event: event, item: Item.create!(description: "รายละเอียด", name: "ของ #{i}", starting_price: 100, reserve_price: 100, status: :available))
    end
  end

  def another_user_joins(lot)
    Participation.create!(user: create_approved_bidder, lot:)
  end

  # ---------- เข้าร่วม ----------

  test "USR-05 กดเข้าร่วมแล้วกลับหน้ารายละเอียดพร้อมข้อความ และมีแถวเข้าร่วม" do
    get lot_path(@lot)
    form = page.at_css("form[action='#{lot_participation_path(@lot)}']")
    assert form, "ต้องมีฟอร์มเข้าร่วม"
    assert_equal "post", form["method"]
    assert_not join_button["disabled"], "ปุ่มต้องกดได้"

    assert_difference -> { Participation.active.count }, 1 do
      post lot_participation_path(@lot)
    end
    assert_redirected_to lot_path(@lot)
    follow_redirect!
    assert_equal "เข้าร่วมประมูลเรียบร้อย", flash_text
    assert_equal @user.id, Participation.active.find_by!(lot: @lot).user_id
  end

  test "หลังเข้าร่วมหน้ารายละเอียดแสดงว่าเข้าร่วมแล้ว ปุ่มเข้าร่วมหาย และนับผู้เข้าร่วม" do
    post lot_participation_path(@lot)
    get lot_path(@lot)
    assert_nil join_button
    assert_includes page.text, "คุณเข้าร่วมประมูลสินค้านี้แล้ว"
    participants = page.css(".ui-dl dt").find { |dt| dt.text == "ผู้เข้าร่วม" }.next_element.text
    assert_equal "1 / 50 คน", participants
  end

  test "USR-06 เข้าร่วมซ้ำไม่ได้ ได้ข้อความและยังมีแถวเดียว" do
    post lot_participation_path(@lot)
    assert_no_difference -> { Participation.count } do
      post lot_participation_path(@lot)
    end
    follow_redirect!
    assert_equal "คุณเข้าร่วมสินค้านี้แล้ว", flash_text
  end

  # ---------- ยกเลิก ----------

  test "USR-06 หน้ารายละเอียดมีหน้าต่างยืนยันก่อนยกเลิกการเข้าร่วม (NFR-13)" do
    post lot_participation_path(@lot)
    get lot_path(@lot)
    dialog = page.at_css("dialog.ui-dialog")
    assert dialog, "ต้องมีหน้าต่างยืนยัน"
    assert_equal "ยกเลิกการเข้าร่วมประมูลสินค้านี้?", dialog.at_css(".ui-dialog__title").text
    assert dialog.at_css(".ui-dialog__message").text.present?
    form = dialog.at_css("form")
    assert_equal lot_participation_path(@lot), form["action"]
    assert_equal "delete", form.at_css("input[name=_method]")["value"]
  end

  test "USR-06 ยกเลิกก่อนเริ่ม: เก็บแถวไว้ใส่ cancelled_at แล้วกลับมาเข้าร่วมใหม่ได้" do
    post lot_participation_path(@lot)
    assert_no_difference -> { Participation.count } do
      delete lot_participation_path(@lot)
    end
    assert_redirected_to lot_path(@lot)
    follow_redirect!
    assert_equal "ยกเลิกการเข้าร่วมแล้ว", flash_text
    assert_equal 0, Participation.active.count
    assert_equal 1, Participation.cancelled.count
    assert join_button, "ยกเลิกแล้วต้องมีปุ่มเข้าร่วมอีกครั้ง"

    assert_difference -> { Participation.active.count }, 1 do
      post lot_participation_path(@lot)
    end
  end

  test "USR-06 หลังเริ่มประมูลยกเลิกไม่ได้ และหน้าไม่มีปุ่มยกเลิก" do
    post lot_participation_path(@lot)
    travel_to @event.starts_at do
      sign_in @user # เลื่อนเวลาไป 1 วัน session เดิมหมดอายุ (AUTH-16) จึง login ใหม่
      delete lot_participation_path(@lot)
      follow_redirect!
      assert_equal "ยกเลิกได้เฉพาะการเข้าร่วมที่ยังไม่ยกเลิกและก่อนการประมูลเริ่ม", flash_text
      assert_equal 1, Participation.active.count
      get lot_path(@lot)
      assert_nil page.at_css("dialog")
      assert_includes page.text, "ยกเลิกไม่ได้หลังเริ่มประมูล"
    end
  end

  test "ยกเลิกสินค้าที่ไม่ได้เข้าร่วมได้ 404" do
    delete lot_participation_path(@lot)
    assert_response :not_found
  end

  # ---------- USR-07: ห้องเต็ม ----------

  test "USR-07 ห้องเต็ม: ปุ่มเข้าร่วมกดไม่ได้ แสดง เต็มแล้ว และเข้าร่วมตรงๆ ไม่ได้" do
    lot, = small_room_lots
    another_user_joins(lot)

    get lot_path(lot)
    assert_nil join_button
    full_button = page.css("button").find { |b| b.text == "เต็มแล้ว" }
    assert full_button
    assert full_button["disabled"]

    assert_no_difference -> { Participation.count } do
      post lot_participation_path(lot)
    end
    follow_redirect!
    assert_equal "เต็มแล้ว", flash_text
  end

  test "USR-07 คนที่อยู่ใน event แล้วเข้าร่วมสินค้าอื่นของ event เดียวกันได้แม้ห้องเต็ม" do
    lot_a, lot_b = small_room_lots
    post lot_participation_path(lot_a)
    get lot_path(lot_b)
    assert join_button, "คนเดิมของ event เข้าร่วมสินค้าเพิ่มได้ ไม่นับเป็นที่นั่งใหม่"
    assert_difference -> { Participation.active.count }, 1 do
      post lot_participation_path(lot_b)
    end
  end

  test "USR-07 มีคนยกเลิก ที่นั่งว่างและปุ่มกลับมา" do
    lot, = small_room_lots
    other = another_user_joins(lot)
    get lot_path(lot)
    assert_nil join_button
    other.cancel!
    get lot_path(lot)
    assert join_button
  end

  # ---------- เวลา ----------

  test "O-8 เข้าร่วมหลังเริ่มประมูลได้จนปิดรับราคา แต่เลยเวลาแล้วไม่ได้" do
    travel_to @event.starts_at + 5.seconds do
      sign_in @user
      get lot_path(@lot)
      assert_nil join_button, "USR-05: หน้ารายละเอียดมีปุ่มเฉพาะก่อนเริ่ม"
      assert_difference -> { Participation.active.count }, 1 do
        post lot_participation_path(@lot)
      end
    end
    travel_to @event.bidding_ends_at + 1.second do
      other = create_approved_bidder
      sign_in other
      assert_no_difference -> { Participation.count } do
        post lot_participation_path(@lot)
      end
      follow_redirect!
      assert_equal "สินค้านี้ปิดรับการเข้าร่วมแล้ว", flash_text
    end
  end

  # ---------- สิทธิ์ ----------

  test "lot ที่ผู้ใช้มองไม่เห็นเข้าร่วมไม่ได้ (404)" do
    post lot_participation_path(lots(:finished_lamp))
    assert_response :not_found
    assert_equal 0, Participation.count
  end

  test "NFR-08 ยังไม่ login ถูกส่งไปหน้า login และไม่เกิดการเข้าร่วม" do
    delete logout_path
    post lot_participation_path(@lot)
    assert_redirected_to login_path
    assert_equal 0, Participation.count
  end

  test "QUAL-05 ผู้ที่ยังไม่ผ่านการตรวจคุณสมบัติเข้าร่วมไม่ได้" do
    sign_in create_bidder
    post lot_participation_path(@lot)
    assert_redirected_to qualification_path
    assert_equal 0, Participation.count
  end

  test "NFR-08 admin เข้าร่วมประมูลไม่ได้ (403)" do
    sign_in create_admin
    post lot_participation_path(@lot)
    assert_response :forbidden
    assert_equal 0, Participation.count
  end

  test "ผู้ใช้ที่ถูกระงับกดเข้าร่วมแล้วไม่เกิดการเข้าร่วม" do
    @user.update_columns(suspended_at: Time.current)
    post lot_participation_path(@lot)
    assert_equal 0, Participation.count
  end
end
