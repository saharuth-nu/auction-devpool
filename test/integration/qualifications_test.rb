require "test_helper"

# #34 #35 QUAL-02/03a/04/06/08/09/12/15 หน้าสถานะและฟอร์มกรอกทรัพย์สินของผู้ประมูล
class QualificationsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin
    @user = create_bidder
  end

  def submit_assets(rows)
    post qualification_path, params: { submission: { assets: rows.each_with_index.to_h { |row, i| [ i.to_s, row ] } } }
  end

  test "QUAL-02/06: ยังไม่กรอก → เห็นฟอร์มกรอกทรัพย์สิน (หลายแถว)" do
    sign_in(@user)
    get qualification_path
    assert_response :success
    assert_select "h1", /ตรวจสอบคุณสมบัติ/
    assert_select "input[name='submission[assets][0][name]']"
    assert_select "input[name='submission[assets][4][value]']"
    assert_select ".ui-badge", "รอกรอกทรัพย์สิน"
  end

  test "QUAL-02: login ครั้งถัดไปยังเห็นฟอร์มจนกว่าจะส่ง" do
    sign_in(@user)
    delete logout_path
    sign_in(@user)
    follow_redirect!
    assert_redirected_to qualification_path
    follow_redirect!
    assert_select "input[name='submission[assets][0][name]']"
  end

  test "QUAL-04: ส่งสำเร็จ → รอ admin ตรวจ แถวว่างถูกละเว้น และรับมูลค่าคั่นหลักพัน" do
    sign_in(@user)
    assert_difference -> { QualificationSubmission.count }, 1 do
      submit_assets([ { name: "บ้าน", value: "3,000,000" }, { name: "รถ", value: "450000.50" }, { name: "", value: "" } ])
    end
    assert_redirected_to qualification_path
    assert @user.reload.qualification_awaiting_review?
    assert_equal BigDecimal("3450000.50"), @user.latest_qualification_submission.total_value

    follow_redirect!
    assert_select ".ui-alert", /อยู่ระหว่างการตรวจสอบคุณสมบัติ/
    assert_select "td", "บ้าน"
    assert_select "input[name='submission[assets][0][name]']", false, "รอตรวจแล้วต้องไม่มีฟอร์ม"
  end

  test "QUAL-03a: ข้อมูลผิดแสดง error ใต้ช่องของแถวนั้น และคงค่าที่กรอกไว้" do
    sign_in(@user)
    assert_no_difference -> { QualificationSubmission.count } do
      submit_assets([ { name: "บ้าน", value: "100" }, { name: "รถ", value: "-5" }, { name: "", value: "50.123" } ])
    end
    assert_response :unprocessable_entity
    assert_select "input[name='submission[assets][1][value]'][value='-5'][aria-invalid='true']"
    assert_select ".ui-field__error", /มากกว่า 0/
    assert_select ".ui-field__error", /ต้องกรอก/ # แถวที่ 3 มีมูลค่าแต่ไม่มีชื่อ
    assert @user.reload.qualification_awaiting_assets?
  end

  test "QUAL-02: ส่งทั้งหมดว่างแจ้งว่าต้องมีอย่างน้อย 1 รายการ" do
    sign_in(@user)
    submit_assets([ { name: "", value: "" } ])
    assert_response :unprocessable_entity
    assert_select ".ui-alert", /อย่างน้อย 1 รายการ/
  end

  test "QUAL-12: รอ admin ตรวจแล้วส่งทรัพย์สินซ้ำไม่ได้ (request ตรงก็ถูกปฏิเสธ)" do
    QualificationSubmission.submit(@user, [ { name: "บ้าน", value: "100" } ])
    sign_in(@user)
    assert_no_difference -> { QualificationSubmission.count } do
      submit_assets([ { name: "บ้านหลังใหม่", value: "999999" } ])
    end
    assert_redirected_to qualification_path
    assert_equal "ไม่สามารถส่งทรัพย์สินได้ในสถานะปัจจุบัน", flash[:alert]
  end

  test "QUAL-08/09/15: ไม่ผ่าน → เห็นเหตุผล ฟอร์มเติมรายการรอบก่อน และส่งใหม่เป็นรอบใหม่" do
    QualificationSubmission.submit(@user, [ { name: "คอนโด", value: "2500000" } ]).reject!(@admin, "มูลค่าสูงเกินจริง")
    sign_in(@user)
    get qualification_path
    assert_select ".ui-alert", /มูลค่าสูงเกินจริง/
    assert_select "input[name='submission[assets][0][name]'][value='คอนโด']"
    assert_select "input[name='submission[assets][0][value]'][value='2500000']"

    assert_difference -> { @user.qualification_submissions.count }, 1 do
      submit_assets([ { name: "คอนโด", value: "1800000" } ])
    end
    assert @user.reload.qualification_awaiting_review?
  end

  test "admin ส่งทรัพย์สินแทนไม่ได้ (เฉพาะ bidder)" do
    sign_in(@admin)
    submit_assets([ { name: "บ้าน", value: "1" } ])
    assert_response :forbidden
  end
end
