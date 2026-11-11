# โหมดปิดปรับปรุง (NFR-20): ตั้ง MAINTENANCE_MODE=1 แล้ว restart ทุก request ได้ 503 หน้าไทย
# อยู่ใน middleware หน้าสุดและไม่แตะฐานข้อมูล จึงใช้ได้ตอน migrate/restore · /up ยังตอบปกติให้ load balancer
module Middleware
  class MaintenanceMode
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless enabled? && env["PATH_INFO"] != "/up"

      html = ErrorsController.render(:maintenance, layout: "error")
      [ 503, { "content-type" => "text/html; charset=utf-8", "retry-after" => "600", "cache-control" => "no-store" }, [ html ] ]
    end

    private

    def enabled? = ENV["MAINTENANCE_MODE"].to_s.match?(/\A(1|true|on)\z/i)
  end
end
