#!/usr/bin/env ruby
# frozen_string_literal: true

# RailsAuditLog performance benchmark suite
#
# Usage:
#   bundle exec rake dev:setup
#   bundle exec ruby benchmarks/suite.rb
#   bundle exec rake dev:reset   # restore seeds afterwards
#
# PaperTrail is loaded automatically when present (development group).
# Benchmarks isolate each library using disable blocks so only one
# auditing system writes per measurement.

require "benchmark/ips"
require_relative "../spec/dummy/config/environment"
# PaperTrail must load after Rails env. Its Railtie won't fire post-boot,
# so we manually require the AR framework to define PaperTrail::Version.
require "paper_trail"
require "paper_trail/frameworks/active_record"

ActiveRecord::Base.logger = nil  # suppress SQL noise

puts "=" * 60
puts "RailsAuditLog vs PaperTrail Benchmark Suite"
puts "Ruby      #{RUBY_VERSION}"
puts "Rails     #{Rails.version}"
puts "Adapter   #{ActiveRecord::Base.connection.adapter_name}"
puts "PaperTrail #{PaperTrail::VERSION}"
puts "=" * 60
puts

# ── Helpers ───────────────────────────────────────────────────────────────────

def cleanup
  RailsAuditLog::AuditLogEntry.delete_all
  PaperTrail::Version.delete_all
  Post.delete_all
end

def without_paper_trail(&block)
  PaperTrail.enabled = false
  block.call
ensure
  PaperTrail.enabled = true
end

def without_rails_audit_log(&block)
  RailsAuditLog.disable(&block)
end

def median(values)
  sorted = values.sort
  mid    = sorted.size / 2
  sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
end

# ── 1. Write throughput — create ─────────────────────────────────────────────

puts "── 1. Write throughput: create ──"
cleanup

Benchmark.ips do |bm|
  bm.config(time: 5, warmup: 1)

  bm.report("rails_audit_log — create") do
    without_paper_trail do
      p = Post.create!(title: "bench")
      p.destroy!
    end
  end

  bm.report("paper_trail       — create") do
    without_rails_audit_log do
      p = Post.create!(title: "bench")
      p.destroy!
    end
  end

  bm.compare!
end

puts

# ── 2. Write throughput — update ─────────────────────────────────────────────

puts "── 2. Write throughput: update ──"
cleanup

ral_post = without_paper_trail { RailsAuditLog.disable { Post.create!(title: "ral") } }
pt_post  = without_rails_audit_log { PaperTrail.enabled = false; p = Post.create!(title: "pt"); PaperTrail.enabled = true; p }

Benchmark.ips do |bm|
  bm.config(time: 5, warmup: 1)

  bm.report("rails_audit_log — update") do
    without_paper_trail { ral_post.update!(title: "x#{rand}") }
  end

  bm.report("paper_trail       — update") do
    without_rails_audit_log { pt_post.update!(title: "x#{rand}") }
  end

  bm.compare!
end

puts

# ── 3. batch_audit vs PaperTrail bulk ────────────────────────────────────────

puts "── 3. 50 creates: batch_audit vs PaperTrail ──"
cleanup

Benchmark.ips do |bm|
  bm.config(time: 5, warmup: 1)

  bm.report("rails_audit_log — batch_audit (1 INSERT)") do
    without_paper_trail do
      RailsAuditLog.batch_audit { 50.times { |i| Post.create!(title: "Post #{i}") } }
    end
    Post.delete_all
    RailsAuditLog::AuditLogEntry.delete_all
  end

  bm.report("rails_audit_log — individual (N INSERTs)") do
    without_paper_trail { 50.times { |i| Post.create!(title: "Post #{i}") } }
    Post.delete_all
    RailsAuditLog::AuditLogEntry.delete_all
  end

  bm.report("paper_trail       — individual (N INSERTs)") do
    without_rails_audit_log { 50.times { |i| Post.create!(title: "Post #{i}") } }
    Post.delete_all
    PaperTrail::Version.delete_all
  end

  bm.compare!
end

puts

# ── 4. Query performance ─────────────────────────────────────────────────────

puts "── 4. Query performance: last 25 entries ──"
cleanup

without_paper_trail do
  RailsAuditLog.batch_audit { 100.times { |i| Post.create!(title: "Post #{i}") } }
end
without_rails_audit_log { 100.times { |i| Post.create!(title: "Post #{i}") } }

Benchmark.ips do |bm|
  bm.config(time: 5, warmup: 1)
  post = Post.first

  bm.report("rails_audit_log — AuditLogEntry.order.limit(25)") do
    RailsAuditLog::AuditLogEntry.order(created_at: :desc).limit(25).load
  end

  bm.report("rails_audit_log — .slim.order.limit(25)") do
    RailsAuditLog::AuditLogEntry.slim.order(created_at: :desc).limit(25).load
  end

  bm.report("paper_trail       — Version.order.limit(25)") do
    PaperTrail::Version.order(created_at: :desc).limit(25).load
  end

  bm.compare!
end

puts

# ── 5. Storage per entry ─────────────────────────────────────────────────────

puts "── 5. Storage per entry ──"
cleanup

without_paper_trail do
  50.times { |i| Post.create!(title: "Benchmark Post #{i}", body: "Body text #{i}.") }
end
without_rails_audit_log do
  50.times { |i| Post.create!(title: "Benchmark Post #{i}", body: "Body text #{i}.") }
end

ral_sample = RailsAuditLog::AuditLogEntry.limit(50).map do |e|
  e.object_changes.to_json.bytesize + e.object.to_json.bytesize
end

pt_sample = PaperTrail::Version.limit(50).map do |v|
  (v.read_attribute_before_type_cast(:object_changes).to_s.bytesize +
   v.read_attribute_before_type_cast(:object).to_s.bytesize)
end

puts "  rails_audit_log  avg: #{(ral_sample.sum.to_f / ral_sample.size).round(1)} bytes  " \
     "median: #{median(ral_sample).round(1)} bytes  (JSON)"
puts "  paper_trail       avg: #{(pt_sample.sum.to_f / pt_sample.size).round(1)} bytes  " \
     "median: #{median(pt_sample).round(1)} bytes  (YAML)"

ral_avg = ral_sample.sum.to_f / ral_sample.size
pt_avg  = pt_sample.sum.to_f / pt_sample.size
savings = ((pt_avg - ral_avg) / pt_avg * 100).round(1)
puts "  Storage savings: #{savings}% smaller with rails_audit_log"
puts

puts "Done. Run `bundle exec rake dev:reset` to restore the development database."
