# หน้ารายละเอียดสินค้าในการประมูล (USR-04, USR-05, issue #58)
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
  end
end
