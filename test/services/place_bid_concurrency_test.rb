require "test_helper"

# NFR-05: "ยื่นครั้งเดียว" ต้องรอดแม้ยิง request ซ้ำพร้อมกัน — พิสูจน์ด้วยหลาย thread บนหลาย connection จริง
#
# ไม่ครอบด้วย transaction ของ test (use_transactional_tests = false) เพื่อให้ทุก thread เห็นข้อมูลที่ commit แล้ว
# จึงต้องล้างข้อมูลที่สร้างเองทั้งหมดด้วย SQL ตรงๆ (ตาราง bids/audit_logs ห้ามลบผ่าน model โดยตั้งใจ)
# ใช้ lot ตัวอย่าง live_painting: event กำลังรับราคา ราคาเริ่มต้น 5,000
class PlaceBidConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  # pool ของ connection มี 5 ตัว (RAILS_MAX_THREADS) และ test เองใช้ 1 ตัว จึงใช้ได้ไม่เกิน 4 thread พร้อมกัน
  THREADS = [ ActiveRecord::Base.connection_pool.size - 1, 4 ].min

  setup do
    @lot = lots(:live_painting)
    @event = @lot.auction_event
    @admin = create_admin
    @users = []
    travel_to(@event.starts_at + 5.seconds, with_usec: true)
  end

  teardown do
    travel_back
    cleanup_created_rows
  end

  def qualified_user
    create_approved_bidder(assets: [ { name: "บ้าน", value: "20000" } ], admin: @admin).tap do |user|
      Participation.create!(user: user, lot: @lot)
      @users << user
    end
  end

  # ปล่อยทุก thread พร้อมกันด้วย latch แล้วรอผลลัพธ์ทั้งหมด
  def run_concurrently(count)
    raise ArgumentError, "ใช้ได้ไม่เกิน #{THREADS} thread ตาม pool ของ connection" if count > THREADS

    ready = Queue.new
    go = Queue.new
    threads = Array.new(count) do |index|
      Thread.new do
        Thread.current.report_on_exception = false
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          yield index
        end
      ensure
        ready << false # ถ้าตายก่อนถึงจุดพร้อม ตัวหลักต้องไม่รอตลอดไป
      end
    end
    count.times { ready.pop(timeout: 10) or raise "thread ไม่พร้อมใน 10 วินาที (connection หมด?)" }
    count.times { go << true }
    threads.map { |thread| thread.join(30) or raise "thread ไม่จบใน 30 วินาที" }.map(&:value)
  end

  test "NFR-05: ผู้ใช้คนเดียวยิงยื่นราคา lot เดียวกันพร้อมกัน สำเร็จได้ครั้งเดียว" do
    user = qualified_user

    results = run_concurrently(THREADS) { |i| PlaceBid.call(user: user, lot: @lot, amount: 6_000 + i) }

    assert_equal 1, results.count(&:ok?), results.map { |r| [ r.error, r.message ] }.inspect
    assert_equal [ :already_bid ] * (THREADS - 1), results.reject(&:ok?).map(&:error)
    assert_equal 1, Bid.where(user_id: user.id, lot_id: @lot.id).count
  end

  test "ผู้ใช้คนละคนยื่น lot เดียวกันพร้อมกัน ทุกคนสำเร็จ (ไม่ล็อกกันเกินจำเป็น)" do
    users = Array.new(THREADS) { qualified_user }

    results = run_concurrently(THREADS) { |i| PlaceBid.call(user: users[i], lot: @lot, amount: 6_000 + i) }

    assert results.all?(&:ok?), results.reject(&:ok?).map { |r| [ r.error, r.message ] }.inspect
    assert_equal THREADS, Bid.where(lot_id: @lot.id, user_id: users.map(&:id)).count
  end

  test "ผู้ใช้ 2 คน ยิงซ้ำคนละหลายครั้งพร้อมกัน ได้คนละ 1 ราคาเท่านั้น" do
    users = Array.new(2) { qualified_user }

    results = run_concurrently(THREADS) { |i| PlaceBid.call(user: users[i % 2], lot: @lot, amount: 6_000 + i) }

    assert_equal 2, results.count(&:ok?)
    users.each { |user| assert_equal 1, Bid.where(user_id: user.id, lot_id: @lot.id).count }
  end

  private

  # ลบเฉพาะแถวที่ test นี้สร้าง (fixtures ไม่แตะ)
  def cleanup_created_rows
    conn = ActiveRecord::Base.connection
    ids = (@users.map(&:id) + [ @admin&.id ]).compact
    return if ids.empty?

    list = ids.join(",")
    submission_ids = conn.select_values("SELECT id FROM qualification_submissions WHERE user_id IN (#{list})")
    conn.execute("DELETE FROM bids WHERE user_id IN (#{list})")
    conn.execute("DELETE FROM participations WHERE user_id IN (#{list})")
    conn.execute("DELETE FROM assets WHERE qualification_submission_id IN (#{submission_ids.join(',')})") if submission_ids.any?
    conn.execute("DELETE FROM qualification_submissions WHERE user_id IN (#{list})")
    conn.execute("DELETE FROM audit_logs WHERE admin_id IN (#{list}) OR (target_type = 'User' AND target_id IN (#{list}))")
    conn.execute("DELETE FROM sessions WHERE user_id IN (#{list})")
    conn.execute("DELETE FROM users WHERE id IN (#{list})")
  end
end
