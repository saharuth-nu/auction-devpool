# จัดการการประมูล (event) ฝั่ง admin (EVT-01–08, EVT-11)
# กฎทั้งหมด (จำนวนสินค้าตามห้อง, สินค้าที่เลือกได้, เวลา, ล็อกหลังเริ่ม) อยู่ที่ AuctionEvent
# TODO(NFR-17): บันทึก audit log เมื่อสร้าง/แก้/ยกเลิก/ลบ event (งาน #71)
class Admin::AuctionEventsController < Admin::BaseController
  before_action :set_event, only: %i[edit update destroy cancel]

  def index
    @events = AuctionEvent.includes(:room, :auction_method).order(starts_at: :desc)
    @lot_counts = Lot.where.not(status: :cancelled).group(:auction_event_id).count
  end

  def new
    @event = AuctionEvent.new(auction_method: AuctionMethod.selectable.first)
  end

  def create
    @event = AuctionEvent.new(event_params)
    if @event.save
      redirect_to admin_auction_events_path, notice: "สร้างการประมูล “#{@event.name}” แล้ว"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @event.update(event_params)
      redirect_to admin_auction_events_path, notice: "บันทึกการประมูล “#{@event.name}” แล้ว"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # EVT-08 / EVT-11: ลบได้เฉพาะ event ที่ยังไม่เริ่ม
  def destroy
    if @event.destroy
      redirect_to admin_auction_events_path, notice: "ลบการประมูล “#{@event.name}” แล้ว"
    else
      redirect_to admin_auction_events_path, alert: @event.errors.full_messages.to_sentence
    end
  end

  # EVT-08: ยกเลิกได้เฉพาะก่อนเริ่ม · สินค้าถูกปล่อยไปใส่ event อื่นได้
  def cancel
    @event.cancel!
    redirect_to admin_auction_events_path, notice: "ยกเลิกการประมูล “#{@event.name}” แล้ว"
  rescue AuctionEvent::InvalidTransition
    redirect_to admin_auction_events_path, alert: "ยกเลิกได้เฉพาะการประมูลที่ยังไม่เริ่ม"
  end

  private

  def set_event
    @event = AuctionEvent.find(params.expect(:id))
  end

  # ฟอร์มที่ไม่ติ๊กสินค้าเลยจะไม่ส่ง selected_item_ids มา: ใช้ [] เพื่อให้ validation แจ้งว่าต้องเลือก
  # ยกเว้น event ที่เริ่มแล้ว: ฟอร์มไม่มีช่องสินค้า (EVT-08) จึงไม่แตะรายการสินค้า
  def event_params
    permitted = params.expect(auction_event: [ :name, :room_id, :auction_method_id, :starts_at, :ends_at, selected_item_ids: [] ])
    permitted[:selected_item_ids] ||= [] if @event.nil? || @event.editable?
    permitted
  end
end
