# เข้าร่วม / ยกเลิกการเข้าร่วมประมูลสินค้าหนึ่งชิ้น (USR-05, 06, 07, issue #59)
# กติกาอยู่ที่ Participation ที่นี่แค่แปลงผลเป็นข้อความบนหน้ารายละเอียดสินค้า
class ParticipationsController < ApplicationController
  allow_roles :bidder
  before_action :set_lot

  def create
    participation = Participation.new(user: current_user, lot: @lot)
    if participation.save
      redirect_to lot_path(@lot), notice: "เข้าร่วมประมูลเรียบร้อย"
    else
      redirect_to lot_path(@lot), alert: participation.errors.map(&:message).to_sentence
    end
  rescue ActiveRecord::RecordNotUnique # ยิงซ้ำพร้อมกัน: unique index กันไว้
    redirect_to lot_path(@lot), alert: "คุณเข้าร่วมสินค้านี้แล้ว"
  end

  def destroy
    Participation.active.find_by!(user: current_user, lot: @lot).cancel!
    redirect_to lot_path(@lot), notice: "ยกเลิกการเข้าร่วมแล้ว"
  rescue Participation::NotCancellable => error
    redirect_to lot_path(@lot), alert: error.message
  end

  private
    # เห็นได้เฉพาะ lot ที่หน้าแรกแสดง ที่เหลือ 404 เหมือนหน้ารายละเอียด
    def set_lot
      @lot = AuctionListing.lots.find(params[:lot_id])
    end
end
