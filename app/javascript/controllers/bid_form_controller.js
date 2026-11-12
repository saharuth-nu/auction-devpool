import { Controller } from "@hotwired/stimulus"

// ฟอร์มยื่นราคา (BID-20, BID-21)
// 1) ตรวจช่วงราคาก่อนส่ง เพื่อไม่ให้ผู้ใช้เสียเวลาในช่วงยื่นราคาสั้นๆ
// 2) ขึ้นหน้าต่างยืนยัน แสดงจำนวนเงินตัวเลขใหญ่ คั่นหลักพัน พร้อมหน่วย "บาท"
// ฝั่งเซิร์ฟเวอร์ตัดสินซ้ำเสมอ (เวลา สิทธิ์ ช่วงราคา ยื่นครั้งเดียว) ขั้นยืนยันนี้ไม่ขยายเวลา
export default class extends Controller {
  static targets = ["amount", "dialog", "confirmAmount", "error"]
  static values = { min: Number, max: Number }

  review(event) {
    event.preventDefault()
    const amount = this.parse(this.amountTarget.value)

    if (amount === null || amount < this.minValue || amount > this.maxValue) {
      this.showError(amount === null
        ? "กรุณากรอกราคาเป็นตัวเลขบาท (ทศนิยมไม่เกิน 2 ตำแหน่ง)"
        : `ราคาต้องอยู่ระหว่าง ${this.format(this.minValue)} ถึง ${this.format(this.maxValue)} บาท`)
      this.amountTarget.focus()
      return
    }

    this.hideError()
    this.confirmAmountTarget.textContent = `${this.format(amount)} บาท`
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  // คลิกพื้นหลัง (ตัว <dialog> เอง ไม่ใช่เนื้อหาข้างใน) = กลับไปแก้ราคา
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  // รับตัวเลขที่คั่นหลักพันได้ เช่น "1,800.50" ไม่ใช่ตัวเลขบาทที่ถูกต้อง → null
  parse(text) {
    const cleaned = text.replace(/[,\s]/g, "")
    return /^\d+(\.\d{1,2})?$/.test(cleaned) ? Number(cleaned) : null
  }

  format(number) {
    return new Intl.NumberFormat("th-TH", { maximumFractionDigits: 2 }).format(number)
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  hideError() {
    this.errorTarget.hidden = true
  }
}
