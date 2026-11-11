import { Controller } from "@hotwired/stimulus"

// นับถอยหลังบนหน้าจอ (แสดงผลเท่านั้น NFR-03): เซิร์ฟเวอร์ส่งจำนวนวินาทีที่เหลือมา เบราว์เซอร์แค่นับลง
// ตัดสินว่าเริ่มแล้วหรือยังเป็นของเซิร์ฟเวอร์เสมอ เมื่อนับถึงศูนย์จึงโหลดหน้าใหม่ให้เซิร์ฟเวอร์ตัดสิน
// รูปแบบข้อความเหมือน MyAuctionsHelper#countdown_text ("1 วัน 02:03:04" / "00:04:15")
export default class extends Controller {
  static values = { remaining: Number }

  connect() {
    this.deadline = performance.now() + this.remainingValue * 1000
    this.render()
    this.timer = setInterval(() => this.render(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
    clearTimeout(this.reloadTimer)
  }

  render() {
    const left = Math.max(0, Math.ceil((this.deadline - performance.now()) / 1000))
    this.element.textContent = this.format(left)
    if (left === 0) {
      clearInterval(this.timer)
      this.reloadTimer = setTimeout(() => window.Turbo.visit(window.location.href, { action: "replace" }), 1500)
    }
  }

  format(total) {
    const days = Math.floor(total / 86400)
    const hours = Math.floor((total % 86400) / 3600)
    const minutes = Math.floor((total % 3600) / 60)
    const seconds = total % 60
    const pad = (n) => String(n).padStart(2, "0")
    const clock = `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`
    return days > 0 ? `${days} วัน ${clock}` : clock
  }
}
