namespace :assistant do
  desc "Remove chat content and usage records older than 30 days"
  task prune: :environment do
    puts "Removed #{AssistantMessage.where(created_at: ...30.days.ago).delete_all} expired chat messages."
  end
end
