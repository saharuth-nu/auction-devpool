import { Controller } from "@hotwired/stimulus"

// แจ้งเตือนเมื่อการเชื่อมต่อแบบเรียลไทม์หลุด และเชื่อมต่อใหม่อัตโนมัติ (NFR-21)
// - Turbo/ActionCable ต่อกลับเองอยู่แล้ว ตัวนี้แค่แสดงแบนเนอร์ และโหลดหน้าห้องใหม่เมื่อกลับมาต่อได้ (กันข้อมูลค้าง)
// - การยื่นราคาเป็น POST ปกติ ไม่พึ่งการเชื่อมต่อนี้ ราคาจึงไม่หายเมื่อสัญญาณหลุด
// ใช้: <div data-controller="connection-status"><div data-connection-status-target="banner" hidden>…</div>
//        <turbo-cable-stream-source …></div>
export default class extends Controller {
  static targets = ["banner"]

  connect() {
    this.wasConnected = false
    this.offline = false
    this.onOffline = () => { this.offline = true; this.render() }
    this.onOnline = () => { this.offline = false; this.render() }
    window.addEventListener("offline", this.onOffline)
    window.addEventListener("online", this.onOnline)

    this.observer = new MutationObserver(() => this.render())
    this.source = this.element.querySelector("turbo-cable-stream-source")
    if (this.source) this.observer.observe(this.source, { attributes: true, attributeFilter: ["connected"] })
    this.render()
  }

  disconnect() {
    window.removeEventListener("offline", this.onOffline)
    window.removeEventListener("online", this.onOnline)
    this.observer?.disconnect()
  }

  get streamConnected() {
    return !this.source || this.source.hasAttribute("connected")
  }

  render() {
    const connected = this.streamConnected && !this.offline
    if (connected) {
      const recovered = this.bannerTarget.hidden === false
      this.wasConnected = true
      this.bannerTarget.hidden = true
      if (recovered) window.Turbo.visit(window.location.href, { action: "replace" }) // ดึงสถานะล่าสุดหลังต่อกลับมา
    } else if (this.wasConnected || this.offline) {
      this.bannerTarget.hidden = false
    }
  }
}
