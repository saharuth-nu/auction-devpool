import { Controller } from "@hotwired/stimulus"

// Select มาตรฐาน (DESIGN.md: Select): ช่องเลือกแบบรายการเปิดลงที่หน้าตาตรงกับ ui-input
// ทำงานเสริมบน <select> เดิม: select จริงยังอยู่ในฟอร์ม (ส่งค่า, validation, ไม่มี JS ก็ใช้ได้) แต่ซ่อนไว้
// คีย์บอร์ด: ↑ ↓ Home End Enter Space Esc Tab พิมพ์ตัวอักษรเพื่อข้าม
export default class extends Controller {
  connect() {
    this.select = this.element
    if (this.select.multiple || this.select.dataset.uiSelectReady) return
    this.select.dataset.uiSelectReady = "true"

    this.wrapper = document.createElement("div")
    this.wrapper.className = "ui-select"
    this.select.parentNode.insertBefore(this.wrapper, this.select)
    this.wrapper.appendChild(this.select)
    this.select.classList.add("ui-select__native")
    this.select.tabIndex = -1
    this.select.setAttribute("aria-hidden", "true")

    this.trigger = document.createElement("button")
    this.trigger.type = "button"
    this.trigger.className = "ui-input ui-select__trigger"
    if (this.select.classList.contains("ui-input--invalid")) this.trigger.classList.add("ui-input--invalid")
    if (this.select.classList.contains("ui-input--sm")) this.trigger.classList.add("ui-input--sm")
    this.trigger.disabled = this.select.disabled
    this.trigger.setAttribute("aria-haspopup", "listbox")
    this.trigger.setAttribute("aria-expanded", "false")
    this.trigger.innerHTML = '<span class="ui-select__value"></span>' +
      '<svg class="ui-select__chevron" viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
    this.valueEl = this.trigger.querySelector(".ui-select__value")

    this.list = document.createElement("ul")
    this.list.className = "ui-select__list"
    this.list.setAttribute("role", "listbox")
    this.list.id = `${this.select.id || "ui-select"}-list`
    this.list.hidden = true
    this.trigger.setAttribute("aria-controls", this.list.id)
    const label = this.select.id && document.querySelector(`label[for="${this.select.id}"]`)
    if (label) {
      label.id ||= `${this.select.id}-label`
      this.trigger.setAttribute("aria-labelledby", label.id)
      this.labelClick = () => this.trigger.focus()
      label.addEventListener("click", this.labelClick)
      this.label = label
    }
    ;["aria-describedby", "aria-invalid"].forEach((a) => this.select.hasAttribute(a) && this.trigger.setAttribute(a, this.select.getAttribute(a)))

    this.wrapper.append(this.trigger, this.list)
    this.build()

    this.onTrigger = (e) => this.toggle(e)
    this.onKey = (e) => this.keydown(e)
    this.onOutside = (e) => { if (!this.wrapper.contains(e.target)) this.close() }
    this.onChange = () => this.sync()
    this.trigger.addEventListener("click", this.onTrigger)
    this.trigger.addEventListener("keydown", this.onKey)
    this.select.addEventListener("change", this.onChange)
    this.select.form?.addEventListener("reset", () => setTimeout(() => this.sync()))
    document.addEventListener("click", this.onOutside)
    this.typed = ""
  }

  disconnect() {
    document.removeEventListener("click", this.onOutside)
    this.label?.removeEventListener("click", this.labelClick)
  }

  build() {
    this.list.replaceChildren()
    this.options = Array.from(this.select.options)
    this.options.forEach((opt, i) => {
      const li = document.createElement("li")
      li.className = "ui-select__option"
      li.setAttribute("role", "option")
      li.id = `${this.list.id}-${i}`
      li.dataset.index = i
      li.textContent = opt.text || " "
      if (opt.disabled) li.setAttribute("aria-disabled", "true")
      li.addEventListener("click", () => this.choose(i))
      li.addEventListener("mousemove", () => this.highlight(i))
      this.list.appendChild(li)
    })
    this.sync()
  }

  sync() {
    const current = this.select.selectedIndex
    const opt = this.options[current]
    this.valueEl.textContent = opt ? opt.text : ""
    this.trigger.classList.toggle("ui-select__trigger--placeholder", !opt || opt.value === "")
    Array.from(this.list.children).forEach((li, i) => li.setAttribute("aria-selected", i === current ? "true" : "false"))
  }

  get isOpen() { return !this.list.hidden }

  toggle(event) {
    event?.preventDefault()
    this.isOpen ? this.close() : this.open()
  }

  open() {
    if (this.trigger.disabled) return
    this.list.hidden = false
    this.trigger.setAttribute("aria-expanded", "true")
    this.wrapper.classList.add("is-open")
    // พลิกขึ้นบนเมื่อที่ด้านล่างไม่พอ
    const room = window.innerHeight - this.trigger.getBoundingClientRect().bottom
    this.wrapper.classList.toggle("ui-select--up", room < Math.min(this.list.offsetHeight + 16, 300))
    this.highlight(Math.max(this.select.selectedIndex, 0))
  }

  close() {
    if (!this.list) return
    this.list.hidden = true
    this.trigger.setAttribute("aria-expanded", "false")
    this.trigger.removeAttribute("aria-activedescendant")
    this.wrapper.classList.remove("is-open")
  }

  highlight(index) {
    this.active = index
    Array.from(this.list.children).forEach((li, i) => li.classList.toggle("is-active", i === index))
    const li = this.list.children[index]
    if (li) {
      this.trigger.setAttribute("aria-activedescendant", li.id)
      li.scrollIntoView({ block: "nearest" })
    }
  }

  choose(index) {
    const opt = this.options[index]
    if (!opt || opt.disabled) return
    this.select.selectedIndex = index
    this.select.dispatchEvent(new Event("change", { bubbles: true }))
    this.close()
    this.trigger.focus()
  }

  step(delta) {
    let i = this.active ?? this.select.selectedIndex
    do { i += delta } while (this.options[i]?.disabled)
    if (i >= 0 && i < this.options.length) this.highlight(i)
  }

  keydown(event) {
    const { key } = event
    if (!this.isOpen) {
      if (["ArrowDown", "ArrowUp", "Enter", " "].includes(key)) { event.preventDefault(); this.open() }
      else if (key.length === 1) this.typeahead(key, false)
      return
    }
    switch (key) {
      case "ArrowDown": event.preventDefault(); this.step(1); break
      case "ArrowUp": event.preventDefault(); this.step(-1); break
      case "Home": event.preventDefault(); this.highlight(0); break
      case "End": event.preventDefault(); this.highlight(this.options.length - 1); break
      case "Enter": case " ": event.preventDefault(); this.choose(this.active); break
      case "Escape": event.preventDefault(); event.stopPropagation(); this.close(); break
      case "Tab": this.close(); break
      default: if (key.length === 1) this.typeahead(key, true)
    }
  }

  typeahead(char, open) {
    clearTimeout(this.typedTimer)
    this.typed += char.toLowerCase()
    this.typedTimer = setTimeout(() => { this.typed = "" }, 600)
    const found = this.options.findIndex((o, i) => !o.disabled && o.text.toLowerCase().startsWith(this.typed) && (i >= 0))
    if (found < 0) return
    if (open) this.highlight(found)
    else this.choose(found)
  }
}
