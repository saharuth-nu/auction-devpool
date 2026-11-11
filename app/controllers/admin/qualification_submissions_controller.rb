# คิวตรวจคุณสมบัติของ admin — task #36
# QUAL-07 รายการรอบที่ "รอ admin ตรวจ" + ทรัพย์สิน + ผ่าน/ไม่ผ่าน · QUAL-08 ไม่ผ่านต้องมีเหตุผล
# NFR-13 ทั้งสองปุ่มมีขั้นยืนยัน · NFR-17 ลง audit log (ทำใน QualificationSubmission#approve!/reject!)
class Admin::QualificationSubmissionsController < Admin::BaseController
  include Paginated

  before_action :set_submission, only: %i[show approve reject]

  def index
    @submissions, @pagination = paginate(QualificationSubmission.review_queue)
  end

  def show
    @history = @submission.user.qualification_submissions.newest_first.where.not(id: @submission.id)
  end

  def approve
    @submission.approve!(current_user)
    redirect_to admin_qualification_submissions_path, status: :see_other,
                notice: "อนุมัติคุณสมบัติของ “#{@submission.user.username}” แล้ว"
  rescue QualificationSubmission::NotReviewable => e
    redirect_to admin_qualification_submission_path(@submission), status: :see_other, alert: e.message
  end

  def reject
    @submission.reject!(current_user, params.dig(:rejection, :reason).to_s.strip)
    redirect_to admin_qualification_submissions_path, status: :see_other,
                notice: "ไม่ผ่านคุณสมบัติของ “#{@submission.user.username}” แล้ว"
  rescue QualificationSubmission::NotReviewable => e
    redirect_to admin_qualification_submission_path(@submission), status: :see_other, alert: e.message
  rescue ActiveRecord::RecordInvalid
    @rejection_error = @submission.errors[:rejection_reason].first || "ต้องระบุเหตุผล"
    @submission.reload
    show
    render :show, status: :unprocessable_entity
  end

  private

  def set_submission
    @submission = QualificationSubmission.includes(:assets, :user).find(params[:id])
  end
end
