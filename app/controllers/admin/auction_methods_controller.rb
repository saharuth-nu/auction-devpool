# วิธีการประมูล: ดู / เพิ่ม / เปิด-ปิดใช้งาน (METH-01/02/03)
# ไม่มี edit/destroy: event เดิมอ้างถึงวิธีประมูลอยู่ ปิดใช้งานแทน (METH-06)
# TODO(NFR-17): บันทึก audit log เมื่อเพิ่ม/เปิด/ปิดวิธีประมูล (งาน #71)
class Admin::AuctionMethodsController < Admin::BaseController
  before_action :set_auction_method, only: %i[enable disable]

  def index
    @auction_methods = AuctionMethod.order(:code)
  end

  def new
    @auction_method = AuctionMethod.new
  end

  def create
    @auction_method = AuctionMethod.new(auction_method_params)
    if @auction_method.save
      redirect_to admin_auction_methods_path, notice: "เพิ่มวิธีประมูล “#{@auction_method.name}” แล้ว"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def enable
    @auction_method.enable!
    redirect_to admin_auction_methods_path, notice: "เปิดใช้งาน “#{@auction_method.name}” แล้ว"
  end

  def disable
    @auction_method.disable!
    redirect_to admin_auction_methods_path, notice: "ปิดใช้งาน “#{@auction_method.name}” แล้ว (event เดิมไม่กระทบ)"
  end

  private

  def set_auction_method
    @auction_method = AuctionMethod.find(params[:id])
  end

  def auction_method_params
    params.expect(auction_method: %i[code name bidding_seconds])
  end
end
