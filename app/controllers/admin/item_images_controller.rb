# ลบรูปสินค้าทีละรูป (ITEM-07)
class Admin::ItemImagesController < Admin::BaseController
  def destroy
    item = Item.find(params[:item_id])
    item.images.find(params[:id]).purge_later
    redirect_to edit_admin_item_path(item), notice: "ลบรูปแล้ว"
  end
end
