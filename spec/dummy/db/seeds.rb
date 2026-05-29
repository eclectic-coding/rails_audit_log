puts "Seeding dummy app..."

RailsAuditLog::AuditLogEntry.delete_all
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

puts "  #{User.count} users"
puts "  #{Post.count} posts"
puts "  #{Article.count} articles (only: [:title])"
puts "  #{RailsAuditLog::AuditLogEntry.count} audit log entries"
puts "Done."
