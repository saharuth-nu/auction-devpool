require "test_helper"

# NFR-17: การกระทำของ admin กับสินค้าและวิธีประมูลต้องลง audit log (#44, #48, #49, #51)
class AdminMasterDataAuditTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin
    sign_in(@admin)
  end

  def last_log = AuditLog.newest_first.first

  def assert_logged(action, target)
    log = last_log
    assert_equal action, log.action
    assert_equal @admin, log.admin
    assert_equal [ target.class.name, target.id ], [ log.target_type, log.target_id ]
    log
  end

  test "สร้างสินค้าลง log" do
    assert_difference -> { AuditLog.count }, 1 do
      post admin_items_path, params: { item: { name: "พัดลม", description: "พัดลมตั้งโต๊ะ", starting_price: "100", reserve_price: "150" } }
    end
    log = assert_logged("item.create", Item.order(:id).last)
    assert_equal "พัดลม", log.change_set["name"]
  end

  test "สร้างสินค้าไม่สำเร็จไม่ลง log" do
    assert_no_difference -> { AuditLog.count } do
      post admin_items_path, params: { item: { name: "", starting_price: "100", reserve_price: "50" } }
    end
  end

  test "แก้ราคาสินค้าลง log พร้อมราคาเดิม→ใหม่ (NFR-17)" do
    item = items(:car)
    patch admin_item_path(item), params: { item: { name: "รถยนต์", starting_price: "310000", reserve_price: "350000" } }
    log = assert_logged("item.update", item)
    assert_equal [ "300000.0", "310000.0" ], log.change_set["starting_price"]
    assert_not log.change_set.key?("reserve_price"), "ค่าที่ไม่เปลี่ยนไม่ต้องลง"
  end

  test "เพิ่ม/ลบรูปสินค้าลง log จำนวนรูปเดิม→ใหม่" do
    item = items(:car)
    patch admin_item_path(item), params: { item: { name: item.name, images: [ fixture_file_upload("photo.png", "image/png") ] } }
    assert_equal [ 0, 1 ], assert_logged("item.update", item).change_set["images"]

    delete admin_item_image_path(item, item.reload.images.first)
    assert_equal [ 1, 0 ], assert_logged("item.update", item).change_set["images"]
  end

  test "เลื่อนลำดับรูปลง log ลำดับเดิม→ใหม่" do
    item = items(:car)
    item.images.attach(fixture_file_upload("photo.png", "image/png"), fixture_file_upload("photo.png", "image/png"))
    first, second = item.reload.ordered_images
    patch move_admin_item_image_path(item, second, direction: "up")
    log = assert_logged("item.update", item)
    assert_equal [ [ first.id, second.id ], [ second.id, first.id ] ], log.change_set["image_order"]
  end

  test "บันทึกโดยไม่เปลี่ยนอะไรไม่ลง log" do
    item = items(:car)
    assert_no_difference -> { AuditLog.count } do
      patch admin_item_path(item), params: { item: { name: item.name } }
    end
  end

  test "อนุมัติสินค้าลง log สถานะเดิม→ใหม่" do
    item = items(:watch)
    patch approve_admin_item_path(item)
    log = assert_logged("item.approve", item)
    assert_equal [ "awaiting_approval", "available" ], log.change_set["status"]
  end

  test "อนุมัติไม่สำเร็จไม่ลง log" do
    assert_no_difference -> { AuditLog.count } do
      patch approve_admin_item_path(items(:car))
    end
  end

  test "เก็บถาวรสินค้าลง log" do
    patch archive_admin_item_path(items(:car))
    assert_logged("item.archive", items(:car))
  end

  test "ลบสินค้าลง log พร้อมชื่อและราคา (สินค้าหายไปแล้วยังรู้ว่าลบอะไร)" do
    item = items(:car)
    delete admin_item_path(item)
    log = assert_logged("item.destroy", item)
    assert_equal "รถยนต์", log.change_set["name"]
    assert_equal "300000.0", log.change_set["starting_price"]
  end

  test "ลบสินค้าไม่สำเร็จไม่ลง log" do
    assert_no_difference -> { AuditLog.count } do
      delete admin_item_path(items(:painting))
    end
  end

  test "เปิด/ปิดวิธีประมูลลง log" do
    method = auction_methods(:first_price)
    patch disable_admin_auction_method_path(method)
    assert_equal [ true, false ], assert_logged("auction_method.disable", method).change_set["enabled"]

    patch enable_admin_auction_method_path(method)
    assert_equal [ false, true ], assert_logged("auction_method.enable", method).change_set["enabled"]
  end

  test "ถ้าลง log ไม่สำเร็จ การกระทำต้องถูกยกเลิกด้วย" do
    item = items(:watch)
    original = AuditLog.method(:record!)
    AuditLog.define_singleton_method(:record!) { |**| raise ActiveRecord::RecordInvalid, AuditLog.new }
    begin
      patch approve_admin_item_path(item)
    ensure
      AuditLog.define_singleton_method(:record!, original)
    end
    assert_response :unprocessable_entity
    assert item.reload.awaiting_approval?
  end
end
