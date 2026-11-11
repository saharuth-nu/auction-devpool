# จัดการบัญชี admin: รายชื่อ (ADM-03) และสร้าง admin ใหม่ (AUTH-07)
# บัญชี admin มีเฉพาะ username + password (ADM-04) · ไม่มี destroy (ADM-06) ปิดใช้งานผ่าน DisablementsController
# NFR-17: การสร้าง admin ลง audit log
class Admin::AdminsController < Admin::BaseController
  def index
    @admins = User.admin.order(:username).includes(:disabled_by)
  end

  def new
    @admin = User.new(role: :admin)
  end

  def create
    @admin = User.new(admin_params.merge(role: :admin))
    if @admin.save
      AuditLog.record!(admin: current_user, action: "admin.create", target: @admin,
                       change_set: { username: @admin.username })
      redirect_to admin_admins_path, notice: "สร้างบัญชี admin “#{@admin.username}” แล้ว"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def admin_params
    params.expect(user: %i[username password password_confirmation])
  end
end
