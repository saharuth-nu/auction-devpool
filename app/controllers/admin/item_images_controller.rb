# จัดการรูปสินค้าทีละรูป: ลบ / เลื่อนลำดับ (ITEM-07) · ลง audit log เป็นการแก้ไขสินค้า (NFR-17)
class Admin::ItemImagesController < Admin::BaseController
  include ItemAuditing

  before_action :set_item

  def destroy
    image = @item.images.find(params[:id])
    Item.transaction do
      before = @item.images.count
      image.purge_later
      audit_item!("item.update", "images" => [ before, before - 1 ])
    end
    redirect_to edit_admin_item_path(@item), notice: "ลบรูปแล้ว"
  end

  def move
    Item.transaction do
      before = @item.ordered_images.map(&:id)
      @item.move_image!(params[:id], params[:direction])
      after = @item.ordered_images.map(&:id)
      audit_item!("item.update", "image_order" => [ before, after ]) if after != before
    end
    redirect_to edit_admin_item_path(@item)
  end

  private

  def set_item
    @item = Item.find(params[:item_id])
  end
end
