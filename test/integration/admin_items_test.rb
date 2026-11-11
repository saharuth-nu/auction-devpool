require "test_helper"

# #48 ITEM-01/03/06 · #49 ITEM-04 · #50 ITEM-07/08 · #51 ITEM-09/12 (ส่วนเก็บถาวร)
class AdminItemsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin
    sign_in(@admin)
  end

  def photo = fixture_file_upload("photo.png", "image/png")

  def item_params(**overrides)
    { item: { name: "กล้องฟิล์ม", description: "สภาพดี", starting_price: "1500.50", reserve_price: "2000" }.merge(overrides) }
  end

  # ---- รายการ + ตัวกรอง (ITEM-01/03)

  test "ITEM-01/03: รายการแสดงสถานะ ราคา และซ่อนสินค้าที่เก็บถาวร" do
    get admin_items_path
    assert_response :success
    assert_select "tr", text: /นาฬิกาข้อมือ/ do
      assert_select ".ui-badge--warning", "รออนุมัติ"
      assert_select "td.num", "1,000 บาท"
    end
    assert_select "tr", text: /ภาพวาด/ do
      assert_select ".ui-badge", "อยู่ระหว่างการประมูล"
    end
    assert_select "td", text: /แจกันโบราณ/, count: 0
  end

  test "ITEM-03: กรองตามสถานะได้" do
    get admin_items_path(status: "available")
    assert_response :success
    assert_select "td", text: /รถยนต์/
    assert_select "td", text: /นาฬิกาข้อมือ/, count: 0
    assert_select "td", text: /ภาพวาด/, count: 0
  end

  test "ITEM-12: ดูสินค้าที่เก็บถาวรได้แยกต่างหาก" do
    get admin_items_path(archived: 1)
    assert_select "td", text: /แจกันโบราณ/
    assert_select "td", text: /รถยนต์/, count: 0
  end

  test "หน้ารายละเอียดแสดงราคาและผู้อนุมัติ" do
    item = items(:watch)
    item.approve!(by: @admin)
    get admin_item_path(item)
    assert_response :success
    assert_select "dd", /1,500 บาท/
    assert_select "dd", /#{@admin.username}/
  end

  test "NFR-13: ลบและเก็บถาวรต้องผ่านหน้าต่างยืนยันที่บอกผลลัพธ์" do
    item = items(:car)
    get admin_item_path(item)
    assert_select ".ui-confirm dialog form[action=?]", admin_item_path(item)
    assert_select ".ui-confirm dialog form[action=?]", archive_admin_item_path(item)
    assert_select "[data-turbo-confirm]", count: 0
  end

  test "NFR-13: อนุมัติต้องผ่านหน้าต่างยืนยัน" do
    item = items(:watch)
    get admin_item_path(item)
    assert_select ".ui-confirm dialog form[action=?]", approve_admin_item_path(item) do
      assert_select "input[name=_method][value=patch]"
    end
  end

  test "NFR-13: ลบรูปต้องผ่านหน้าต่างยืนยัน" do
    item = items(:car)
    item.images.attach(photo)
    get edit_admin_item_path(item)
    assert_select ".ui-confirm dialog form[action=?]", admin_item_image_path(item, item.images.first)
  end

  # ---- เพิ่ม / แก้ (ITEM-01/04/05/06/07)

  test "ITEM-04/05/07: เพิ่มสินค้าพร้อมหลายรูป เริ่มที่ รออนุมัติ" do
    get new_admin_item_path
    assert_response :success

    assert_difference -> { Item.count }, 1 do
      post admin_items_path, params: item_params(images: [ photo, photo ])
    end
    item = Item.order(:id).last
    assert_redirected_to admin_item_path(item)
    assert item.awaiting_approval?
    assert_equal BigDecimal("1500.50"), item.starting_price
    assert_equal 2, item.images.count
  end

  test "ITEM-06: ราคาขั้นต่ำต่ำกว่าราคาเริ่มต้นแสดง error และไม่บันทึก" do
    assert_no_difference -> { Item.count } do
      post admin_items_path, params: item_params(starting_price: "2000", reserve_price: "1999")
    end
    assert_response :unprocessable_entity
    assert_select ".ui-field__error"
  end

  test "ITEM-08: ไฟล์ที่ไม่ใช่รูปถูกปฏิเสธ" do
    assert_no_difference -> { Item.count } do
      post admin_items_path, params: item_params(images: [ fixture_file_upload("notes.txt", "text/plain") ])
    end
    assert_response :unprocessable_entity
    assert_select ".ui-field__error", /JPG, PNG หรือ WebP/
  end

  test "ITEM-01: แก้ไขสินค้าได้ และรูปเดิมยังอยู่เมื่อเพิ่มรูปใหม่" do
    item = items(:car)
    item.images.attach(photo)
    get edit_admin_item_path(item)
    assert_response :success

    patch admin_item_path(item), params: item_params(
      name: "รถยนต์ (ใหม่)", images: [ item.images.first.signed_id, photo ]
    )
    assert_redirected_to admin_item_path(item)
    assert_equal "รถยนต์ (ใหม่)", item.reload.name
    assert_equal 2, item.images.count
  end

  test "ITEM-09: สินค้าที่อยู่ระหว่างการประมูลแก้ราคาไม่ได้" do
    item = items(:painting)
    patch admin_item_path(item), params: item_params(name: "ภาพวาด", starting_price: "1", reserve_price: "1")
    assert_response :unprocessable_entity
    assert_select ".ui-field__error", /ระหว่างการประมูล/
    assert_equal BigDecimal("5000"), item.reload.starting_price
  end

  # ---- อนุมัติ (ITEM-04)

  test "ITEM-04: อนุมัติแล้วเป็น พร้อมขาย และบันทึกผู้อนุมัติ" do
    item = items(:watch)
    patch approve_admin_item_path(item)
    assert_redirected_to admin_item_path(item)
    assert item.reload.available?
    assert_equal @admin, item.approved_by
  end

  test "ITEM-04: อนุมัติสินค้าที่ไม่ได้รออนุมัติไม่ได้" do
    item = items(:car)
    patch approve_admin_item_path(item)
    assert_redirected_to admin_item_path(item)
    assert_equal "อนุมัติได้เฉพาะสินค้าที่รออนุมัติ", flash[:alert]
    assert_nil item.reload.approved_by
  end

  # ---- ลบ / เก็บถาวร (ITEM-01/09/12)

  test "ITEM-01: ลบสินค้าที่ยังไม่เข้าประมูลได้" do
    assert_difference -> { Item.count }, -1 do
      delete admin_item_path(items(:car))
    end
    assert_redirected_to admin_items_path
  end

  test "ITEM-09: ลบสินค้าที่อยู่ระหว่างการประมูลไม่ได้" do
    assert_no_difference -> { Item.count } do
      delete admin_item_path(items(:painting))
    end
    assert_redirected_to admin_item_path(items(:painting))
    assert_match(/ระหว่างการประมูล/, flash[:alert])
  end

  test "NFR-19/ITEM-12: สินค้าที่เคยอยู่ใน event (มี lot) ลบไม่ได้ แจ้งให้เก็บถาวรแทนเป็นภาษาไทย" do
    assert_no_difference -> { Item.count } do
      delete admin_item_path(items(:lamp)) # lamp ขายแล้วใน event ที่จบ ไม่ได้อยู่ระหว่างประมูล
    end
    assert_redirected_to admin_item_path(items(:lamp))
    assert_match(/เก็บถาวรแทน/, flash[:alert])
  end

  test "ITEM-12: เก็บถาวรได้ แต่สินค้าที่อยู่ระหว่างการประมูลเก็บไม่ได้" do
    patch archive_admin_item_path(items(:car))
    assert items(:car).reload.archived?

    patch archive_admin_item_path(items(:painting))
    assert_not items(:painting).reload.archived?
    assert_match(/ระหว่างการประมูล/, flash[:alert])
  end

  # ---- ลบรูป (ITEM-07)

  test "ITEM-07: ลบรูปทีละรูปได้" do
    item = items(:car)
    item.images.attach(photo, photo)
    delete admin_item_image_path(item, item.images.first)
    assert_redirected_to edit_admin_item_path(item)
    assert_equal 1, item.reload.images.count
  end

  test "ITEM-07: เลื่อนลำดับรูปได้" do
    item = items(:car)
    item.images.attach(photo, photo)
    first, second = item.reload.ordered_images

    patch move_admin_item_image_path(item, second, direction: "up")
    assert_redirected_to edit_admin_item_path(item)
    assert_equal [ second.id, first.id ], item.reload.ordered_images.map(&:id)
  end

  # ---- สิทธิ์ (NFR-08)

  test "ผู้ใช้ทั่วไปเข้าหน้าและสั่งการสินค้าไม่ได้" do
    delete logout_path
    sign_in(create_bidder)
    item = items(:watch)

    get admin_items_path
    assert_response :forbidden
    post admin_items_path, params: item_params
    assert_response :forbidden
    patch approve_admin_item_path(item)
    assert_response :forbidden
    delete admin_item_path(item)
    assert_response :forbidden
    assert item.reload.awaiting_approval?
  end
end
