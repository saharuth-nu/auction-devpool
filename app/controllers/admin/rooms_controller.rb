# ห้องประมูล: ดู / เพิ่ม / แก้ / ลบ / เก็บถาวร (ROOM-01/02/05)
# TODO(ROOM-03/04): ห้ามลบหรือลดจำนวนต่ำกว่าที่ event ที่ยังไม่จบใช้อยู่ (รอโมเดล AuctionEvent #53, งาน #46)
# TODO(NFR-17): บันทึก audit log (งาน #71)
class Admin::RoomsController < Admin::BaseController
  before_action :set_room, only: %i[edit update destroy archive]

  def index
    @show_archived = params[:archived].present?
    @rooms = (@show_archived ? Room.archived : Room.active).order(:name)
  end

  def new
    @room = Room.new
  end

  def create
    @room = Room.new(room_params)
    if @room.save
      redirect_to admin_rooms_path, notice: "เพิ่มห้อง “#{@room.name}” แล้ว"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @room.update(room_params)
      redirect_to admin_rooms_path, notice: "บันทึกห้อง “#{@room.name}” แล้ว"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @room.destroy!
    redirect_to admin_rooms_path, notice: "ลบห้อง “#{@room.name}” แล้ว"
  end

  def archive
    @room.archive!
    redirect_to admin_rooms_path, notice: "เก็บถาวรห้อง “#{@room.name}” แล้ว"
  end

  private

  def set_room
    @room = Room.find(params[:id])
  end

  def room_params
    params.expect(room: %i[name description max_participants max_items])
  end
end
