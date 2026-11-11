# สินค้าประมูล: ดู / กรองสถานะ / เพิ่ม / แก้ / ลบ / อนุมัติ / เก็บถาวร (ITEM-01/03/04/09/12)
# รูปส่งเป็น signed_id ของรูปเดิม + ไฟล์ใหม่ในช่องเดียวกัน (ไม่ส่งรูปเดิม = ลบ) ลบทีละรูปผ่าน ItemImagesController
# ทุกการเปลี่ยนแปลงลง audit log ใน transaction เดียวกัน: ลง log ไม่สำเร็จ = การกระทำถูกยกเลิก (NFR-17)
class Admin::ItemsController < Admin::BaseController
  include ItemAuditing

  before_action :set_item, except: %i[index new create]

  def index
    @show_archived = params[:archived].present?
    scope = @show_archived ? Item.archived : Item.active
    @status = params[:status].presence_in(Item.statuses.keys)
    @status_counts = scope.group(:status).count
    @total_count = @status_counts.values.sum
    @items = scope.filter_by_status(@status).order(created_at: :desc)
  end

  def show; end

  def new
    @item = Item.new
  end

  def create
    @item = Item.new(item_params)
    saved = Item.transaction do
      next false unless @item.save

      audit_item!("item.create", @item.attributes.slice(*AUDITED_ATTRIBUTES).merge("images" => @item.images.count))
      true
    end

    if saved
      redirect_to admin_item_path(@item), notice: "เพิ่มสินค้า “#{@item.name}” แล้ว (รออนุมัติ)"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    images_before = @item.images.count
    saved = Item.transaction do
      next false unless @item.update(item_params)

      changes = @item.saved_changes.slice(*AUDITED_ATTRIBUTES)
      images_after = @item.images.count
      changes["images"] = [ images_before, images_after ] if images_after != images_before
      audit_item!("item.update", changes) if changes.any?
      true
    end

    if saved
      redirect_to admin_item_path(@item), notice: "บันทึกสินค้า “#{@item.name}” แล้ว"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    snapshot = @item.attributes.slice(*AUDITED_ATTRIBUTES, "status")
    destroyed = Item.transaction do
      next false unless @item.destroy

      audit_item!("item.destroy", snapshot)
      true
    end

    if destroyed
      redirect_to admin_items_path, notice: "ลบสินค้า “#{@item.name}” แล้ว"
    else
      redirect_to admin_item_path(@item), alert: @item.errors.full_messages.to_sentence
    end
  end

  def approve
    Item.transaction do
      @item.approve!(by: current_user)
      audit_item!("item.approve", @item.saved_changes.slice("status"))
    end
    redirect_to admin_item_path(@item), notice: "อนุมัติ “#{@item.name}” แล้ว สินค้าพร้อมขาย"
  rescue Item::InvalidTransition => e
    redirect_to admin_item_path(@item), alert: e.message
  end

  def archive
    Item.transaction do
      @item.archive!
      audit_item!("item.archive", @item.saved_changes.slice("archived_at"))
    end
    redirect_to admin_items_path, notice: "เก็บถาวรสินค้า “#{@item.name}” แล้ว"
  rescue Item::InvalidTransition => e
    redirect_to admin_item_path(@item), alert: e.message
  end

  private

  def set_item
    @item = Item.find(params[:id])
  end

  def item_params
    params.expect(item: [ :name, :description, :starting_price, :reserve_price, images: [] ])
  end
end
