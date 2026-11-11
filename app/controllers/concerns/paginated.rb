# แบ่งหน้าแบบ offset อย่างง่าย (ยังไม่มี gem) ใช้คู่กับ ui_pagination ใน view
#   @users, @pagination = paginate(User.directory(params), per: 25)
module Paginated
  extend ActiveSupport::Concern

  Page = Struct.new(:number, :per, :total_count, keyword_init: true) do
    def total_pages = [ (total_count.to_f / per).ceil, 1 ].max
    def first? = number <= 1
    def last? = number >= total_pages
    def offset = (number - 1) * per
  end

  private

  def paginate(scope, per: 25)
    total = scope.count
    page = Page.new(number: params[:page].to_i.clamp(1, Float::INFINITY), per:, total_count: total)
    page.number = page.total_pages if page.number > page.total_pages
    [ scope.limit(per).offset(page.offset), page ]
  end
end
