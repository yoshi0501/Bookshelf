# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc "Reset database (drop/create/migrate) and load seed data (validation-compliant)"
    task reset: :environment do
      puts "=== db:seed:reset ==="
      puts "1. Running db:drop db:create db:migrate..."
      Rake::Task["db:drop"].invoke
      Rake::Task["db:create"].invoke
      Rake::Task["db:migrate"].invoke
      puts "2. Loading seeds with RESET=1..."
      ENV["RESET"] = "1"
      Rake::Task["db:seed"].invoke
      puts "Done."
    end
  end
end
