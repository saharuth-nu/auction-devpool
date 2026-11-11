require "test_helper"

# #44 METH-01/02/03/06
class AdminAuctionMethodsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin
    sign_in(@admin)
  end

  test "METH-01: รายการวิธีประมูลแสดงชื่อ รหัส ระยะเวลา และสถานะ" do
    auction_methods(:english).update!(enabled: false)

    get admin_auction_methods_path
    assert_response :success
    assert_select "tr", text: /first_price/ do
      assert_select "td", /30 วินาที/
      assert_select ".ui-badge--success", "เปิดใช้งาน"
    end
    assert_select "tr", text: /english/ do
      assert_select ".ui-badge--neutral", "ปิดใช้งาน"
    end
  end

  test "METH-04: บอกได้ว่าวิธีไหนยังไม่มีกติกาจริง (เลือกตอนสร้าง event ไม่ได้)" do
    get admin_auction_methods_path
    assert_select "tr", text: /english/ do
      assert_select ".ui-badge--muted", "ยังไม่รองรับ"
    end
  end

  test "METH-02: เพิ่มวิธีประมูลได้ และเริ่มที่เปิดใช้งาน" do
    get new_admin_auction_method_path
    assert_response :success

    assert_difference -> { AuctionMethod.count }, 1 do
      post admin_auction_methods_path, params: { auction_method: { code: "dutch", name: "ประมูลแบบดัตช์", bidding_seconds: 45 } }
    end
    assert_redirected_to admin_auction_methods_path
    method = AuctionMethod.find_by!(code: "dutch")
    assert method.enabled?
    assert_equal 45, method.bidding_seconds
  end

  test "METH-02: ข้อมูลผิดแสดง error ใต้ช่อง และไม่บันทึก" do
    assert_no_difference -> { AuctionMethod.count } do
      post admin_auction_methods_path, params: { auction_method: { code: "first_price", name: "", bidding_seconds: 0 } }
    end
    assert_response :unprocessable_entity
    assert_select ".ui-field__error", minimum: 3
  end

  test "METH-03: ปิดและเปิดใช้งานได้" do
    method = auction_methods(:first_price)

    patch disable_admin_auction_method_path(method)
    assert_redirected_to admin_auction_methods_path
    assert_not method.reload.enabled?

    patch enable_admin_auction_method_path(method)
    assert_redirected_to admin_auction_methods_path
    assert method.reload.enabled?
  end

  test "ผู้ใช้ทั่วไปเข้าหน้าและสั่งการวิธีประมูลไม่ได้ (NFR-08)" do
    delete logout_path
    sign_in(create_bidder)

    get admin_auction_methods_path
    assert_response :forbidden
    post admin_auction_methods_path, params: { auction_method: { code: "dutch", name: "x", bidding_seconds: 45 } }
    assert_response :forbidden
    patch disable_admin_auction_method_path(auction_methods(:first_price))
    assert_response :forbidden
    assert auction_methods(:first_price).reload.enabled?
    assert_nil AuctionMethod.find_by(code: "dutch")
  end
end
