require "rails_helper"
require "rails_audit_log/matchers"

RSpec.describe RailsAuditLog::Matchers do
  include RailsAuditLog::Matchers

  describe "have_audit_log_entry" do
    let(:post) { Post.create!(title: "Hello") }

    it "passes when the record has any audit entry" do
      expect(post).to have_audit_log_entry
    end

    it "fails when the record has no entries" do
      new_post = Post.new
      allow(new_post).to receive(:audit_log_entries)
        .and_return(RailsAuditLog::AuditLogEntry.none)
      matcher = have_audit_log_entry
      expect(matcher.matches?(new_post)).to be false
    end

    it "scopes to a specific event type" do
      expect(post).to have_audit_log_entry(:create)
      expect(post).not_to have_audit_log_entry(:update)
    end

    it "chains .touching to filter by changed attribute" do
      post.update!(title: "World")
      expect(post).to have_audit_log_entry(:update).touching(:title)
      expect(post).not_to have_audit_log_entry(:update).touching(:body)
    end

    it "describes itself" do
      expect(have_audit_log_entry(:update).touching(:title).description)
        .to eq("have an audit log entry with event 'update' touching 'title'")
    end

    it "has a meaningful failure message" do
      matcher = have_audit_log_entry(:update).touching(:title)
      matcher.matches?(post)
      expect(matcher.failure_message).to include("Post")
      expect(matcher.failure_message).to include("update")
      expect(matcher.failure_message).to include("title")
    end

    it "has a meaningful negated failure message" do
      post.update!(title: "World")
      matcher = have_audit_log_entry(:update).touching(:title)
      matcher.matches?(post)
      expect(matcher.failure_message_when_negated).to include("not to have")
    end
  end

  describe "create_audit_log_entry" do
    it "passes when the block creates any audit entry" do
      expect { Post.create!(title: "New") }.to create_audit_log_entry
    end

    it "fails when the block creates no entry" do
      matcher = create_audit_log_entry
      result = matcher.matches?(-> { RailsAuditLog.disable { Post.create!(title: "Silent") } })
      expect(result).to be false
    end

    it "scopes to a specific event via keyword" do
      post = Post.create!(title: "Hello")
      expect { post.update!(title: "World") }.to create_audit_log_entry(event: :update)
      expect { Post.create!(title: "Another") }.not_to create_audit_log_entry(event: :update)
    end

    it "scopes to a touched attribute via keyword" do
      post = Post.create!(title: "Hello")
      expect { post.update!(title: "World") }.to create_audit_log_entry(touching: :title)
    end

    it "chains .touching after the constructor" do
      post = Post.create!(title: "Hello")
      expect { post.update!(title: "World") }
        .to create_audit_log_entry(event: :update).touching(:title)
    end

    it "describes itself" do
      expect(create_audit_log_entry(event: :update).touching(:title).description)
        .to eq("create an audit log entry with event 'update' touching 'title'")
    end

    it "has a meaningful failure message" do
      post = Post.create!(title: "Hello")
      matcher = create_audit_log_entry(event: :update)
      matcher.matches?(-> { Post.create!(title: "Create, not update") })
      expect(matcher.failure_message).to include("update")
      expect(matcher.failure_message).to include("none was created")
    end

    it "has a meaningful negated failure message" do
      matcher = create_audit_log_entry(event: :create)
      matcher.matches?(-> { Post.create!(title: "Hello") })
      expect(matcher.failure_message_when_negated).to include("not to create")
    end
  end
end
