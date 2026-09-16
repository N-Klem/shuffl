# Real-card demo catalogue. Repeated imports preserve candidate corrections and
# update live cards by source_key; old records remain for wallets and quiz history.
CardCandidate.import_file!(Rails.root.join("data/real_cards/catalogue.json"))
Card.publish_us_demo!
Stack.import_demo!
puts "Published #{Card.available.count} US cards. Historical cards and stacks retained."
