# ผลการประมูลของผู้ใช้ (USR-11..15, BID-12, BID-18, BID-19, issue #61)
#
# - เปิดดูได้เฉพาะ event ที่สรุปผลแล้ว และเฉพาะผู้ที่เข้าร่วม event นั้น (ผู้อื่นได้ 404) ผลของ event ที่ยังไม่สรุปไปการประมูลของฉัน
# - ต่อ lot แสดง: ชนะ / ไม่ชนะ / ไม่ขาย (Lot#outcome_for), ราคาผู้ชนะ (เฉพาะที่ขายได้ ไม่เปิดตัวตนผู้ชนะ BID-12)
#   และราคาที่ผู้ใช้ยื่นเอง (เห็นเฉพาะของตัวเอง BID-11, USR-13)
# - ไม่ขาย: แสดงเพียง "ไม่ขาย" ไม่มีราคาสูงสุด จำนวนผู้ยื่น หรือเหตุผล (BID-19) · ไม่มี reserve ที่ใดเลย (BID-18)
# - แจ้งผลที่หน้านี้เท่านั้น ไม่มี email/push (USR-14) · ผู้ชนะยังไม่มีปุ่มชำระเงินใน M1 (USR-15)
class AuctionResultsController < ApplicationController
  allow_roles :bidder

  # รายการ event ที่สรุปผลแล้วและผู้ใช้เข้าร่วม (เมนู "ผลการประมูล" USR-17)
  def index
    event_ids = Participation.active.where(user_id: current_user.id).joins(:lot).select("lots.auction_event_id")
    @events = AuctionEvent.settled.where(id: event_ids).includes(:room).order(settled_at: :desc, id: :desc)
    @outcomes = outcomes_by_event(@events)
  end

  def show
    @event = AuctionEvent.includes(:room).find(params[:auction_event_id])
    raise ActiveRecord::RecordNotFound, "ไม่มีผลของการประมูลที่ถูกยกเลิก" if @event.cancelled?
    return redirect_to(my_auctions_path, alert: "การประมูลนี้ยังไม่สรุปผล") unless @event.settled?

    participations = Participation.active.where(user_id: current_user.id).joins(:lot)
                                  .where(lots: { auction_event_id: @event.id }).includes(lot: :item).order("lots.id")
    raise ActiveRecord::RecordNotFound, "ไม่ได้เข้าร่วมการประมูลนี้" if participations.empty?

    @lots = participations.map(&:lot)
    # ราคาที่ยื่นของผู้ใช้คนนี้เท่านั้น (BID-11, USR-13) ผ่าน Bid.visible_to
    @my_bids = Bid.visible_to(current_user).where(lot_id: @lots.map(&:id)).index_by(&:lot_id)
  end

  private

  # event_id => { won: n, lost: n, unsold: n } ของผู้ใช้คนนี้ (นับเฉพาะ lot ที่เข้าร่วม)
  def outcomes_by_event(events)
    lots = Lot.where(auction_event_id: events.map(&:id), id: Participation.active.where(user_id: current_user.id).select(:lot_id))
    lots.group_by(&:auction_event_id).transform_values do |list|
      list.map { |lot| lot.outcome_for(current_user) }.tally
    end
  end
end
