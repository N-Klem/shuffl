namespace :stacks do
  desc "Build the five curated stacks from published real cards"
  task seed_demo: :environment do
    puts "Imported #{Stack.import_demo!} curated stacks. Historical stacks preserved."
  end
end
