# การประมูลของฉัน (USR-16, issue #62): การเข้าร่วมที่ยังไม่ยกเลิกของผู้ใช้ จัดเป็น 3 กลุ่มตาม event
#
#   upcoming = ยังไม่ถึงเวลาเริ่ม (ยกเลิกการเข้าร่วมได้ USR-06)
#   live     = เริ่มแล้วและยังรับราคาอยู่ (ปุ่ม "เข้าห้องประมูล")
#   finished = จบแล้ว: event สรุปผล/ยกเลิก หรือเลยเวลารับราคาแล้ว (รอสรุปผลก็นับเป็นจบแล้ว)
#
# ตัดสินช่วงเวลาด้วยเวลาของเซิร์ฟเวอร์ผ่าน Clock (NFR-03) · การเข้าร่วมที่ผู้ใช้ยกเลิกเองไม่แสดง
# lot ที่ถูกนำออก/ยกเลิกแสดงต่อไป (เป็นประวัติ) พร้อมสถานะของ lot
# เรียง: ยังไม่เริ่ม/กำลังประมูล = ใกล้ถึงก่อน · จบแล้ว = ล่าสุดก่อน
class MyAuctions
  Group = Data.define(:event, :participations)

  Result = Data.define(:upcoming, :live, :finished) do
    def empty? = [ upcoming, live, finished ].all?(&:empty?)

    def lots = [ upcoming, live, finished ].flatten.flat_map { |group| group.participations.map(&:lot) }
  end

  def self.for(user) = new(user).call

  def initialize(user)
    @user = user
  end

  def call
    groups = participations.group_by { |participation| participation.lot.auction_event }
                           .map { |event, rows| Group.new(event:, participations: rows.sort_by(&:id)) }
    by_phase = groups.group_by { |group| phase(group.event) }
    Result.new(
      upcoming: sorted(by_phase[:upcoming]),
      live: sorted(by_phase[:live]),
      finished: sorted(by_phase[:finished]).reverse
    )
  end

  private
    def participations
      Participation.active.where(user: @user)
                   .includes(lot: [ { item: { images_attachments: :blob } }, { auction_event: %i[room auction_method] } ])
    end

    def phase(event)
      return :finished if event.finished? || Clock.passed?(event.bidding_ends_at)

      Clock.reached?(event.starts_at) ? :live : :upcoming
    end

    def sorted(groups) = Array(groups).sort_by { |group| [ group.event.starts_at, group.event.id ] }
end
