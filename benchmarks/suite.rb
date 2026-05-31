#!/usr/bin/env ruby
# frozen_string_literal: true

# RailsAuditLog performance benchmark suite
#
# Usage:
#   bundle exec ruby benchmarks/suite.rb
#
# Requires the dummy app database to exist:
#   bundle exec rake dev:setup
#
# Optional PaperTrail comparison:
#   Add gem "paper_trail" to the Gemfile, run bundle install, then re-run.
#   PaperTrail::Version must use the audit_log_entries table alias, or
#   configure a separate :paper_trail_versions table.

require "benchmark/ips"
require_relative "../spec/dummy/config/environment"

ActiveRecord::Base.logger = nil  # suppress SQL noise

ITERATIONS = 500

puts "=" * 60
puts "RailsAuditLog Benchmark Suite"
puts "Ruby    #{RUBY_VERSION}"
puts "Rails   #{Rails.version}"
puts "Adapter #{ActiveRecord::Base.connection.adapter_name}"
puts "=" * 60
puts

# ── Helpers ──────────────────────────────────────────────────────────────────

def cleanup
  RailsAuditLog::AuditLogEntry.delete_all
  Post.delete_all
end

def median(values)
  sorted = values.sort
  mid    = sorted.size / 2
  sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
end

# ── 1. Write throughput ───────────────────────────────────────────────────────

puts "── 1. Write throughput (individual) ──"
cleanup

Benchmark.ips do |bm|
  bm.config(time: 5, warmup: 1)

  bm.report("create (sync)") do
    RailsAuditLog.disable { Post.create!(title: "bench") }.tap do |p|
      RailsAuditLog::AuditLogEntry.create!(
        event: "create", item_type: "Post", item_id: p.id,
        object_changes: { "title" => [nil, "bench"] }
      )
      p.delete
      RailsAuditLog::AuditLogEntry.where(item_id: p.id, item_type: "Post").delete_all
    end
  end

  bm.report("create via Auditable") do
    p = Post.create!(title: "bench")
    p.destroy!
  end

  bm.report("update via Auditable") do
    p = RailsAuditLog.disable { Post.create!(title: "x") }
    p.update!(title: "y")
    p.destroy!
  end

  bm.compare!
end

puts

# ── 2. Batch audit ───────────────────────────────────────────────────────────

puts "── 2. batch_audit vs individual writes ──"
cleanup

Benchmark.ips do |bm|
  bm.config(time: 5, warmup: 1)

  bm.report("50 creates — individual") do
    50.times { |i| Post.create!(title: "Post #{i}") }
    Post.delete_all
    RailsAuditLog::AuditLogEntry.where(item_type: "Post").delete_all
  end

  bm.report("50 creates — batch_audit") do
    RailsAuditLog.batch_audit do
      50.times { |i| Post.create!(title: "Post #{i}") }
    end
    Post.delete_all
    RailsAuditLog::AuditLogEntry.where(item_type: "Post").delete_all
  end

  bm.compare!
end

puts

# ── 3. Query performance ─────────────────────────────────────────────────────

puts "── 3. Query performance ──"
cleanup

# Seed data
RailsAuditLog.batch_audit do
  100.times { |i| Post.create!(title: "Post #{i}") }
end

Benchmark.ips do |bm|
  bm.config(time: 5, warmup: 1)

  post = Post.first

  bm.report("AuditLogEntry.order(created_at: :desc).limit(25)") do
    RailsAuditLog::AuditLogEntry.order(created_at: :desc).limit(25).load
  end

  bm.report("record.audit_log_entries (all for one record)") do
    post.audit_log_entries.load
  end

  bm.report(".slim.order(created_at: :desc).limit(25)") do
    RailsAuditLog::AuditLogEntry.slim.order(created_at: :desc).limit(25).load
  end

  bm.compare!
end

puts

# ── 4. Storage efficiency ────────────────────────────────────────────────────

puts "── 4. Storage per audit entry ──"
cleanup

100.times { |i| Post.create!(title: "Benchmark Post #{i}", body: "Some body text for post #{i}.") }

total_entries = RailsAuditLog::AuditLogEntry.count
sample = RailsAuditLog::AuditLogEntry.limit(50).map do |e|
  e.object_changes.to_json.bytesize + (e.object.to_json.bytesize rescue 0)
end

avg_bytes = sample.sum.to_f / sample.size
puts "  Entries sampled : #{[sample.size, total_entries].min}"
puts "  Avg object_changes + object (JSON): #{avg_bytes.round(1)} bytes"
puts "  Median: #{median(sample).round(1)} bytes"
puts "  Note: PaperTrail stores the same data as YAML (~30-50% larger)"
puts

# ── 5. version_at ────────────────────────────────────────────────────────────

puts "── 5. version_at (time-travel reconstruction) ──"

post = Post.first
10.times { |i| post.update!(title: "v#{i + 2}") }

Benchmark.ips do |bm|
  bm.config(time: 3, warmup: 1)
  t = Time.current

  bm.report("RailsAuditLog.version_at(record, time)") do
    RailsAuditLog.version_at(post, t)
  end
end

puts
puts "Done. Run `bundle exec rake dev:reset` to restore the development database."
