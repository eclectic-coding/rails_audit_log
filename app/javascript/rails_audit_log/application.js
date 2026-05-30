import "@hotwired/turbo"
import { Application } from "@hotwired/stimulus"
import SearchController from "rails_audit_log/search_controller"

const application = Application.start()
application.register("search", SearchController)