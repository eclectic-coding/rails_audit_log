puts "Seeding dummy app..."

RailsAuditLog::AuditLogEntry.delete_all
Comment.delete_all if defined?(Comment)
Post.delete_all
User.delete_all
Article.delete_all if defined?(Article)

alice = User.create!(name: "Alice")
bob   = User.create!(name: "Bob")
admin = User.create!(name: "Admin")

# Posts track all attributes (minus updated_at by default)
RailsAuditLog.with_actor(alice) do
  post1 = Post.create!(title: "Hello World", body: "First post body.")
  Post.create!(title: "Getting Started", body: "A beginner's guide.")
  post1.update!(title: "Hello World (edited)", body: "Updated body.")
end

RailsAuditLog.with_actor(bob) do
  post3 = Post.create!(title: "Bob's Post", body: "Written by Bob.")
  post3.update!(body: "Bob updated this post.")
  post3.destroy!
end

RailsAuditLog.with_actor(admin) do
  Post.create!(title: "Admin Notice", body: "This is an admin post.")
end

Post.create!(title: "Anonymous Post", body: "No actor context.")

# Articles use `audit_log only: [:title]` — body and status changes are silent
RailsAuditLog.with_actor(alice) do
  article = Article.create!(title: "My Article", body: "Body not tracked.", status: "draft")
  article.update!(body: "Updated body — no audit entry created.")
  article.update!(title: "My Article (revised)", status: "published")
end

# Demonstrate disable: bulk-insert posts without audit noise
RailsAuditLog.disable do
  3.times { |i| Post.create!(title: "Bulk post #{i + 1}", body: "Created silently.") }
end

# Demonstrate skip_audit_log on an instance
post = Post.first
post.skip_audit_log { post.update!(body: "Silent body change.") }

# Demonstrate 0.5.0 — reason field
RailsAuditLog.with_actor(admin) do
  approved = Post.create!(title: "Policy Update", body: "Draft policy.")
  RailsAuditLog.audit_log_reason("Approved by legal") do
    approved.update!(title: "Policy Update (approved)", body: "Final policy.")
  end
  RailsAuditLog.audit_log_reason("Reverted per CEO request") do
    approved.update!(title: "Policy Update", body: "Draft policy.")
  end
end

# Demonstrate 0.4.0 — reify and version chain navigation
puts "  Demonstrating reify and version_at..."
versioned = RailsAuditLog.with_actor(alice) do
  Post.create!(title: "Versioned Post", body: "Initial body.")
end
versioned.update!(title: "Versioned Post (v2)")
versioned.update!(title: "Versioned Post (v3)", body: "Final body.")

entries = versioned.audit_log_entries.order(:id)
puts "  version chain: #{entries.map(&:event).join(' -> ')}"
puts "  reify on update: title before = #{entries.updated_events.first.reify.title.inspect}"
puts "  previous/next: #{entries.second.previous.event} -> #{entries.second.event} -> #{entries.second.next.event}"

t_after_v2 = entries.updated_events.first.created_at
snapshot = RailsAuditLog.version_at(versioned, t_after_v2)
puts "  version_at(after v2 update): title = #{snapshot.title.inspect}"

# Demonstrate 0.6.0 — association tracking (Post has audit_log associations: true)
puts "  Demonstrating association tracking..."
RailsAuditLog.with_actor(alice) do
  assoc_post = Post.create!(title: "Association Demo")
  comment1   = assoc_post.comments.create!(body: "First comment — tracked as add")
  comment2   = assoc_post.comments.create!(body: "Second comment — tracked as add")
  assoc_post.comments.delete(comment1)  # tracked as remove
end

puts "  #{User.count} users"
puts "  #{Post.count} posts"
puts "  #{Comment.count} comments"
puts "  #{Article.count} articles (only: [:title])"
puts "  #{RailsAuditLog::AuditLogEntry.count} audit log entries"
puts "Done."