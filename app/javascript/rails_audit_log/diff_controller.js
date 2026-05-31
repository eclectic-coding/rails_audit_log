import { Controller } from "@hotwired/stimulus"

export default class DiffController extends Controller {
  static targets = ["inline", "side", "inlineBtn", "sideBtn"]

  connect() {
    this.setMode(localStorage.getItem("ral-diff-mode") || "inline")
  }

  setInline() { this.setMode("inline") }
  setSide()   { this.setMode("side") }

  setMode(mode) {
    localStorage.setItem("ral-diff-mode", mode)
    this.inlineTarget.hidden = mode !== "inline"
    this.sideTarget.hidden   = mode !== "side"
    this.inlineBtnTarget.classList.toggle("ral-diff-btn--active", mode === "inline")
    this.sideBtnTarget.classList.toggle("ral-diff-btn--active", mode === "side")
  }
}