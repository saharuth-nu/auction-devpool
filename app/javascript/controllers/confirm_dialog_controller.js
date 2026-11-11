import { Controller } from "@hotwired/stimulus"

// หน้าต่างยืนยันของ ui_confirm_button (NFR-13)
// ใช้ <dialog> ของเบราว์เซอร์: โฟกัสถูกล็อกในหน้าต่าง, Esc ปิดได้เอง, มี ::backdrop ให้
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  // คลิกพื้นหลัง (ตัว <dialog> เอง ไม่ใช่เนื้อหาข้างใน) = ยกเลิก
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
