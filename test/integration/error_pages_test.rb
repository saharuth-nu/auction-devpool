require "test_helper"

# #79 NFR-20: หน้า error / session หมดอายุ / ปิดปรับปรุง เป็นภาษาไทยตามมาตรฐาน UI
class ErrorPagesTest < ActionDispatch::IntegrationTest
  setup do
    # ทดสอบหน้าที่ผู้ใช้เห็นจริง ไม่ใช่หน้า debug ของ development
    @detailed = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
  end

  teardown { Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @detailed }

  test "NFR-20: 404 เป็นหน้าไทยของระบบ" do
    get "/no-such-page"
    assert_response :not_found
    assert_select ".ui-card__title", "ไม่พบหน้าที่ต้องการ"
    assert_select "a[href=?]", "/", text: "กลับหน้าแรก"
  end

  test "NFR-20: 422 และ 500 เป็นหน้าไทย" do
    { "/422" => [ 422, "ส่งข้อมูลไม่สำเร็จ" ], "/500" => [ 500, "ระบบขัดข้องชั่วคราว" ] }.each do |path, (status, title)|
      get path
      assert_response status
      assert_select ".ui-card__title", title
    end
  end

  test "NFR-20: หน้า error ไม่เผยรายละเอียดภายใน" do
    get "/500"
    %w[Exception backtrace SQLite ActiveRecord].each { |w| assert_not_includes response.body, w }
  end

  test "NFR-20: session หมดอายุ ส่งไป login พร้อมข้อความ แล้วกลับหน้าเดิมหลัง login" do
    user = create_approved_bidder(admin: create_admin)
    sign_in(user)
    user.sessions.update_all(created_at: 13.hours.ago, updated_at: 13.hours.ago)
    get my_auctions_path
    assert_redirected_to login_path
    follow_redirect!
    assert_select ".ui-alert--error", /หมดอายุ/
    sign_in(user)
    assert_redirected_to my_auctions_path
  end

  test "ผู้ที่ไม่เคย login ไป login โดยไม่มีข้อความหมดอายุ" do
    get my_auctions_path
    follow_redirect!
    assert_select ".ui-alert", count: 0
  end

  test "NFR-20: โหมดปิดปรับปรุงตอบ 503 หน้าไทย โดยไม่แตะ DB และ /up ยังปกติ" do
    ENV["MAINTENANCE_MODE"] = "1"
    get "/"
    assert_response :service_unavailable
    assert_select ".ui-card__title", "ปิดปรับปรุงระบบชั่วคราว"
    assert_equal "600", response.headers["Retry-After"]
    get "/up"
    assert_response :success
  ensure
    ENV.delete("MAINTENANCE_MODE")
  end
end
