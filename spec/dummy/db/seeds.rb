puts "Seeding dummy app..."

RailsAuditLog::AuditLogEntry.delete_all
Post.delete_all
User.delete_all

alice = User.create!(name: "Alice")
bob   = User.create!(name: "Bob")
admin = User.create!(name: "Admin")

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

puts "  #{User.count} users"
puts "  #{Post.count} posts"
puts "  #{RailsAuditLog::AuditLogEntry.count} audit log entries"
puts "Done."
