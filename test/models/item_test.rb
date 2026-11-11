require "test_helper"

class ItemTest < ActiveSupport::TestCase
  def build(**attrs)
    Item.new({ name: "กล้องถ่ายรูป", starting_price: 1000, reserve_price: 1200 }.merge(attrs))
  end

  def image(name: "photo.jpg", content_type: "image/jpeg", bytes: 1.kilobyte)
    { io: StringIO.new("x" * bytes), filename: name, content_type: content_type }
  end

  # --- สถานะ (ITEM-02, ITEM-04) ---

  test "สินค้าใหม่เริ่มที่ รออนุมัติ (ITEM-04)" do
    item = build
    item.save!
    assert item.awaiting_approval?
  end

  test "มีสถานะครบ 4 ค่าตามลำดับ (ITEM-02)" do
    assert_equal %w[awaiting_approval available in_auction sold], Item.statuses.keys
  end

  test "อนุมัติแล้วเป็น พร้อมขาย และบันทึก admin กับเวลาที่อนุมัติ (ITEM-04)" do
    item = items(:watch)
    admin = create_admin
    freeze_time do
      item.approve!(by: admin)
      assert item.reload.available?
      assert_equal Time.current, item.approved_at
      assert_equal admin, item.approved_by
    end
  end

  test "อนุมัติได้เฉพาะสินค้าที่ รออนุมัติ" do
    item = items(:car)
    assert_raises(Item::InvalidTransition) { item.approve!(by: create_admin) }
    assert item.reload.available?
  end

  test "ผู้อนุมัติต้องเป็น admin" do
    assert_raises(Item::InvalidTransition) { items(:watch).approve!(by: create_bidder) }
    assert items(:watch).reload.awaiting_approval?
  end

  # --- ราคา (ITEM-05, ITEM-06, NFR-09) ---

  test "ต้องมีชื่อ ราคาเริ่มต้น และราคาขั้นต่ำ (ITEM-05)" do
    item = build(name: "", starting_price: nil, reserve_price: nil)
    assert_not item.valid?
    assert item.errors.of_kind?(:name, :blank)
    assert item.errors.of_kind?(:starting_price, :blank)
    assert item.errors.of_kind?(:reserve_price, :blank)
  end

  test "ราคาทั้งสองต้องมากกว่า 0 (ITEM-06)" do
    assert_not build(starting_price: 0, reserve_price: 0).valid?
    assert_not build(starting_price: -100, reserve_price: 100).valid?
  end

  test "ราคาขั้นต่ำต้องไม่ต่ำกว่าราคาเริ่มต้น (ITEM-06)" do
    item = build(starting_price: 1000, reserve_price: 999.99)
    assert_not item.valid?
    assert item.errors.of_kind?(:reserve_price, :greater_than_or_equal_to)

    assert build(starting_price: 1000, reserve_price: 1000).valid?
  end

  test "ราคาเก็บเป็น decimal ไม่ใช่ float (NFR-09)" do
    item = build(starting_price: "1234.56", reserve_price: "2000")
    item.save!
    assert_kind_of BigDecimal, item.reload.starting_price
    assert_equal BigDecimal("1234.56"), item.starting_price
  end

  # --- ตัวกรองสถานะ (ITEM-03) ---

  test "กรองตามสถานะได้ และค่าว่าง/ไม่รู้จักคืนทั้งหมด (ITEM-03)" do
    assert_equal [ items(:watch) ], Item.filter_by_status("awaiting_approval").to_a
    assert_equal Item.count, Item.filter_by_status(nil).count
    assert_equal Item.count, Item.filter_by_status("bogus").count
  end

  # --- ล็อกระหว่างประมูล (ITEM-09) ---

  test "สินค้าที่อยู่ระหว่างการประมูลแก้ราคาไม่ได้ (ITEM-09)" do
    item = items(:painting)
    item.starting_price = 4000
    assert_not item.valid?
    assert item.errors.of_kind?(:starting_price, :locked_during_auction)

    item.reload.reserve_price = 9000
    assert_not item.valid?
    assert item.errors.of_kind?(:reserve_price, :locked_during_auction)
  end

  test "สินค้าที่อยู่ระหว่างการประมูลยังแก้ชื่อ/รายละเอียดได้" do
    assert items(:painting).update(description: "เพิ่มรายละเอียด")
  end

  test "สินค้าที่อยู่ระหว่างการประมูลลบไม่ได้ (ITEM-09)" do
    item = items(:painting)
    assert_not item.destroy
    assert Item.exists?(item.id)
  end

  test "สินค้าที่ยังไม่เข้าประมูลแก้ราคาและลบได้" do
    item = items(:car)
    assert item.update(starting_price: 310000, reserve_price: 360000)
    assert item.destroy
  end

  # --- เก็บถาวร (ITEM-12) ---

  test "เก็บถาวรแล้วหายจากรายการปกติ แต่ยังหาเจอด้วย id (ITEM-12)" do
    item = items(:car)
    item.archive!
    assert item.archived?
    assert_not_includes Item.active, item
    assert_equal item, Item.find(item.id)
  end

  test "สินค้าที่อยู่ระหว่างการประมูลเก็บถาวรไม่ได้" do
    assert_raises(Item::InvalidTransition) { items(:painting).archive! }
  end

  # --- รูป (ITEM-07, ITEM-08) ---

  test "แนบรูปได้มากกว่า 1 รูป (ITEM-07)" do
    item = build
    item.images.attach(image(name: "a.jpg"), image(name: "b.png", content_type: "image/png"),
                       image(name: "c.webp", content_type: "image/webp"))
    assert item.save
    assert_equal 3, item.images.count
  end

  test "รับเฉพาะ JPG/PNG/WebP (ITEM-08)" do
    item = build
    item.images.attach(image(name: "doc.pdf", content_type: "application/pdf"))
    assert_not item.valid?
    assert item.errors.of_kind?(:images, :invalid_content_type)
  end

  test "รูปละไม่เกิน 5 MB (ITEM-08)" do
    ok = build
    ok.images.attach(image(bytes: 5.megabytes))
    assert ok.valid?

    too_big = build
    too_big.images.attach(image(bytes: 5.megabytes + 1))
    assert_not too_big.valid?
    assert too_big.errors.of_kind?(:images, :file_too_large)
  end

  test "ไม่เกิน 10 รูปต่อสินค้า (ITEM-08)" do
    ok = build
    ok.images.attach(Array.new(10) { |i| image(name: "#{i}.jpg") })
    assert ok.valid?

    too_many = build
    too_many.images.attach(Array.new(11) { |i| image(name: "#{i}.jpg") })
    assert_not too_many.valid?
    assert too_many.errors.of_kind?(:images, :too_many)
  end

  # --- ลำดับรูป (ITEM-07) ---

  def item_with_images(count)
    item = items(:car)
    item.images.attach(Array.new(count) { |i| image(name: "#{i}.jpg") })
    item.reload
  end

  test "รูปเรียงตามลำดับที่อัปโหลดเป็นค่าเริ่มต้น (ITEM-07)" do
    item = item_with_images(3)
    assert_equal %w[0.jpg 1.jpg 2.jpg], item.ordered_images.map { |a| a.filename.to_s }
  end

  test "เลื่อนรูปขึ้น/ลงได้ และลำดับคงอยู่หลังโหลดใหม่ (ITEM-07)" do
    item = item_with_images(3)
    third = item.ordered_images.last

    item.move_image!(third.id, :up)
    assert_equal %w[0.jpg 2.jpg 1.jpg], item.reload.ordered_images.map { |a| a.filename.to_s }

    item.move_image!(item.ordered_images.first.id, :down)
    assert_equal %w[2.jpg 0.jpg 1.jpg], item.reload.ordered_images.map { |a| a.filename.to_s }
  end

  test "เลื่อนรูปแรกขึ้นหรือรูปสุดท้ายลงไม่เปลี่ยนอะไร" do
    item = item_with_images(2)
    before = item.ordered_images.map(&:id)
    item.move_image!(before.first, :up)
    item.move_image!(before.last, :down)
    assert_equal before, item.reload.ordered_images.map(&:id)
  end

  test "รูปที่เพิ่มทีหลังต่อท้ายลำดับเดิม" do
    item = item_with_images(2)
    item.move_image!(item.ordered_images.last.id, :up)
    item.images.attach(image(name: "new.jpg"))
    assert_equal %w[1.jpg 0.jpg new.jpg], item.reload.ordered_images.map { |a| a.filename.to_s }
  end

  test "เลื่อนรูปที่ไม่ใช่ของสินค้านี้ไม่ได้" do
    item = item_with_images(1)
    assert_raises(ActiveRecord::RecordNotFound) { item.move_image!(-1, :up) }
  end
end
