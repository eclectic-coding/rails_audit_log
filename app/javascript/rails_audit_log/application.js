import "@hotwired/turbo"
import { Application } from "@hotwired/stimulus"
import SearchController from "rails_audit_log/search_controller"
import DiffController   from "rails_audit_log/diff_controller"

const application = Application.start()
application.register("search", SearchController)
application.register("diff",   DiffController)