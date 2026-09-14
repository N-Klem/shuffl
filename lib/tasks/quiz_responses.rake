namespace :quiz_responses do
  desc "Delete anonymous quiz results older than 30 days (signed-in users' results are kept)"
  task prune: :environment do
    stale = QuizResponse.where(user_id: nil).where("completed_at < ?", 30.days.ago)
    puts "Removing #{stale.count} anonymous quiz responses older than 30 days"
    stale.delete_all
  end
end
