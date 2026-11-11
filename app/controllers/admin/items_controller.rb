# สินค้าประมูล: ดู / กรองสถานะ / เพิ่ม / แก้ / ลบ / อนุมัติ / เก็บถาวร (ITEM-01/03/04/09/12)
# รูปส่งเป็น signed_id ของรูปเดิม + ไฟล์ใหม่ในช่องเดียวกัน (ไม่ส่งรูปเดิม = ลบ) ลบทีละรูปผ่าน ItemImagesController
# TODO(ITEM-12): ห้ามลบจริงเมื่อมีประวัติ lot/การเข้าร่วม/ราคาที่ยื่น (รอโมเดล Lot #53)
# TODO(NFR-17): บันทึก audit log รวมราคาเดิม→ใหม่ (งาน #71)
class Admin::ItemsController < Admin::BaseController
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
    if @item.save
      redirect_to admin_item_path(@item), notice: "เพิ่มสินค้า “#{@item.name}” แล้ว (รออนุมัติ)"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @item.update(item_params)
      redirect_to admin_item_path(@item), notice: "บันทึกสินค้า “#{@item.name}” แล้ว"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @item.destroy
      redirect_to admin_items_path, notice: "ลบสินค้า “#{@item.name}” แล้ว"
    else
      redirect_to admin_item_path(@item), alert: @item.errors.full_messages.to_sentence
    end
  end

  def approve
    @item.approve!(by: current_user)
    redirect_to admin_item_path(@item), notice: "อนุมัติ “#{@item.name}” แล้ว สินค้าพร้อมขาย"
  rescue Item::InvalidTransition => e
    redirect_to admin_item_path(@item), alert: e.message
  end

  def archive
    @item.archive!
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
