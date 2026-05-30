import { Controller } from "@hotwired/stimulus"

export default class SearchController extends Controller {
  filter() {
    clearTimeout(this._timeout)
    this._timeout = setTimeout(() => this.element.requestSubmit(), 300)
  }

  select() {
    this.element.requestSubmit()
  }
}