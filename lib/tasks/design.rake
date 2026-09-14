# Thin wrappers around bin/design-check, which holds the real logic as plain
# Ruby so that git hooks and CI can run it without booting Rails.
namespace :design do
  desc "Check stylesheets against the binding rules in DESIGN.md"
  task :check do
    abort unless system(File.expand_path("../../bin/design-check", __dir__))
  end

  desc "Re-record the current violation counts as the new ceiling"
  task :baseline do
    system(File.expand_path("../../bin/design-check", __dir__), "--baseline")
  end
end
