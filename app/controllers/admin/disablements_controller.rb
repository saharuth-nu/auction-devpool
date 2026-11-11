# ปิด / เปิดใช้งานบัญชี admin (ADM-05, 07, 08)
# กฎ: ต้องมีเหตุผล · ปิดตัวเองไม่ได้ · ต้องเหลือ admin ที่ใช้งานได้อย่างน้อย 1 คน (ตรวจใน User#disable)
# TODO(NFR-17): บันทึก audit log (งาน #71 ของสาย B)
class Admin::DisablementsController < Admin::BaseController
  before_action :set_admin

  def new; end

  def create
    if @admin.disable(by: current_user, reason: params.dig(:disablement, :reason))
      redirect_to admin_admins_path, notice: "ปิดใช้งานบัญชี “#{@admin.username}” แล้ว"
    else
      flash.now[:alert] = @admin.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @admin.enable
    redirect_to admin_admins_path, notice: "เปิดใช้งานบัญชี “#{@admin.username}” แล้ว"
  end

  private

  def set_admin
    @admin = User.admin.find(params[:admin_id])
  end
end
