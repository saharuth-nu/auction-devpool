# ยื่นราคา (BID-01..05, SUSP-03, NFR-03, NFR-05) — ทางเข้าเดียวของการสร้าง Bid
#
#   result = PlaceBid.call(user: current_user, lot: lot, amount: params[:amount])
#   result.ok?      # => true/false
#   result.bid      # => Bid ที่บันทึกแล้ว (เมื่อ ok?)
#   result.error    # => :not_started / :closed / :already_bid ... (เมื่อไม่ ok)
#   result.message  # => ข้อความภาษาไทยให้แสดงผู้ใช้
#
# ลำดับการตรวจ (จากถูกต้อนรับ → ข้อมูลที่กรอก): ผู้ใช้ → lot/event → เวลา → เข้าร่วมไว้ → ราคา → บันทึก
#   1. ต้องเป็นผู้ประมูลที่ผ่านตรวจคุณสมบัติและไม่ถูกระงับ (BID-03, SUSP-03)
#   2. event ต้องกำลังเปิดรับราคาและ lot ยังรอการประมูล · ถึงเวลาเริ่มแล้วแต่ job ยังไม่ทำงาน ให้เริ่มให้เลย (start! ทำซ้ำได้ผลเดิม)
#   3. เวลานับจากนาฬิกาเซิร์ฟเวอร์เท่านั้น (Clock): ตั้งแต่เวลาเริ่มถึงเวลาปิดรับราคา (BID-02, NFR-03)
#   4. ต้องเข้าร่วม lot นี้ไว้ก่อน (BID-03)
#   5. ราคา > 0, ไม่ต่ำกว่าราคาเริ่มต้น (BID-05), ไม่เกินเพดานทรัพย์สินรวมของผู้ใช้ (BID-04 ตรวจต่อครั้ง)
#   6. บันทึก: ยื่นได้ครั้งเดียวต่อ (ผู้ใช้, lot) ด้วย unique index (BID-01, NFR-05)
#
# BID-18: ข้อความ error ทุกข้อห้ามเอ่ยถึงราคาขั้นต่ำ (reserve) หรือราคาของคนอื่น
class PlaceBid
  Result = Data.define(:bid, :error, :message) do
    def ok? = error.nil?
  end

  MESSAGES = {
    not_bidder: "เฉพาะผู้ประมูลเท่านั้นที่ยื่นราคาได้",
    not_qualified: "ต้องผ่านการตรวจสอบคุณสมบัติก่อนจึงยื่นราคาได้",
    suspended: "บัญชีถูกระงับ ยื่นราคาไม่ได้",
    closed: "สินค้านี้ปิดรับราคาแล้ว",
    not_started: "การประมูลยังไม่เริ่ม",
    not_joined: "ต้องเข้าร่วมประมูลสินค้านี้ก่อนจึงยื่นราคาได้",
    invalid_amount: "กรุณากรอกราคาเป็นตัวเลขบาท (ทศนิยมไม่เกิน 2 ตำแหน่ง) และมากกว่า 0",
    already_bid: "คุณยื่นราคาสินค้านี้แล้ว ยื่นซ้ำหรือแก้ไขไม่ได้"
  }.freeze

  AMOUNT_FORMAT = /\A\d+(\.\d{1,2})?\z/

  def self.call(user:, lot:, amount:)
    new(user:, lot:, amount:).call
  end

  def initialize(user:, lot:, amount:)
    @user = user
    @lot_id = lot.id
    @raw_amount = amount
  end

  def call
    return failure(:not_bidder) unless @user&.bidder?
    return failure(:not_qualified) unless @user.qualified?
    return failure(:suspended) if @user.suspended?

    @lot = Lot.includes(:item, auction_event: :auction_method).find(@lot_id)
    @event = @lot.auction_event
    @event.start! if @event.scheduled? && Clock.reached?(@event.starts_at)
    @lot.reload # start! อาจถอน lot ที่สินค้าไม่พร้อม

    return failure(:closed) unless @event.bidding? || @event.scheduled?
    return failure(:closed) unless @lot.pending?
    return failure(:not_started) if @event.scheduled?

    now = Clock.now
    return failure(:closed) if now > @event.bidding_ends_at # ปิดรับแล้ว (BID-02)

    return failure(:not_joined) unless Participation.active.exists?(user_id: @user.id, lot_id: @lot.id)

    amount = parse_amount(@raw_amount)
    return failure(:invalid_amount) if amount.nil? || !amount.positive?

    floor = @lot.item.starting_price
    return failure(:invalid_amount, "ราคาต้องไม่ต่ำกว่า #{baht(floor)}") if amount < floor

    ceiling = @user.bid_ceiling
    return failure(:invalid_amount, "ราคาต้องไม่เกินวงเงินของคุณ #{baht(ceiling)}") if amount > ceiling

    save(amount, now)
  end

  private

  def save(amount, placed_at)
    Result.new(bid: Bid.create!(user: @user, lot: @lot, amount:, placed_at:), error: nil, message: nil)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # ยื่นซ้ำ (รวมการยิงพร้อมกัน): unique index ให้สำเร็จได้ครั้งเดียว (NFR-05)
    failure(:already_bid)
  end

  # รับค่าที่ผู้ใช้พิมพ์คั่นหลักพัน เช่น "1,800.50" · ไม่ใช่ตัวเลขบาทที่ถูกต้อง → nil
  def parse_amount(raw)
    return BigDecimal(raw.to_s) if raw.is_a?(Numeric)

    text = raw.to_s.delete(", ").strip
    text.match?(AMOUNT_FORMAT) ? BigDecimal(text) : nil
  end

  def baht(value)
    "#{ActiveSupport::NumberHelper.number_to_delimited(value.to_i)} บาท"
  end

  def failure(error, message = nil)
    Result.new(bid: nil, error:, message: message || MESSAGES.fetch(error))
  end
end
