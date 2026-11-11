# หน้ารายละเอียดสินค้าในการประมูล (USR-04, USR-05, USR-07, issues #58, #59)
# เปิดได้เฉพาะ lot ที่หน้าแรกแสดง (AuctionListing.lots) ที่เหลือเป็น 404
# ผู้ที่ยังไม่ผ่านการตรวจคุณสมบัติถูก QualificationGate ส่งไปหน้าสถานะ (QUAL-05)
class LotsController < ApplicationController
  allow_roles :bidder

  def show
    @lot = AuctionListing.lots
                         .includes(item: { images_attachments: :blob }, auction_event: %i[room auction_method])
                         .find(params[:id])
    @item = @lot.item
    @event = @lot.auction_event
    @participation = Participation.active.find_by(user: current_user, lot: @lot)
    @participants = Participation.participants_count(@event)
    # เต็ม = ห้องเต็มและผู้ใช้ยังไม่ได้เป็นผู้เข้าร่วมของ event นี้ (คนเดิมเข้าร่วมสินค้าเพิ่มได้แม้เต็ม, USR-07)
    @full = !Participation.joined?(current_user, @event) && Participation.full?(@event)
  end
end
