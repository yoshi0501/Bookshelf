# frozen_string_literal: true

namespace :users do
  desc "Show user password information (encrypted hash)"
  task :show_password, [:email] => :environment do |_t, args|
    email = args[:email]
    
    if email.blank?
      puts "Usage: rails users:show_password[user@example.com]"
      exit 1
    end

    user = User.find_by(email: email)
    
    if user.nil?
      puts "User not found: #{email}"
      exit 1
    end

    puts "\n=== User Information ==="
    puts "Email: #{user.email}"
    puts "ID: #{user.id}"
    puts "Created: #{user.created_at}"
    puts "Password Changed At: #{user.password_changed_at || 'Never'}"
    puts "\n=== Password Hash (encrypted_password) ==="
    puts user.encrypted_password
    puts "\n=== Password Status ==="
    puts "Password Expired: #{user.password_expired? rescue 'N/A'}"
    puts "Failed Attempts: #{user.failed_attempts}"
    puts "Locked: #{user.locked_at.present? ? "Yes (since #{user.locked_at})" : 'No'}"
    puts "\n=== User Profile ==="
    if user.user_profile
      puts "Name: #{user.user_profile.name}"
      puts "Company: #{user.user_profile.company&.name}"
      puts "Role: #{user.user_profile.role}"
      puts "Status: #{user.user_profile.member_status}"
    else
      puts "No profile found"
    end
  end

  desc "List all users with their email and password change date"
  task list: :environment do
    users = User.includes(:user_profile).order(:email)
    
    puts "\n=== All Users ==="
    puts "%-40s %-20s %-30s %-15s" % ["Email", "Password Changed", "Company", "Status"]
    puts "-" * 105
    
    users.each do |user|
      password_changed = user.password_changed_at&.strftime("%Y-%m-%d %H:%M") || "Never"
      company = user.user_profile&.company&.name || "N/A"
      status = user.user_profile&.member_status || "N/A"
      
      puts "%-40s %-20s %-30s %-15s" % [user.email, password_changed, company, status]
    end
    
    puts "\nTotal: #{users.count} users"
  end

  desc "Seed test database with users"
  task seed_test: :environment do
    if Rails.env.production?
      puts "ERROR: Cannot seed test data in production!"
      exit 1
    end
    
    require_relative "../../db/seeds_test"
  end

  desc "Reset password for a user"
  task :reset_password, [:email, :new_password] => :environment do |_t, args|
    email = args[:email]
    new_password = args[:new_password]
    
    if email.blank? || new_password.blank?
      puts "Usage: rails users:reset_password[user@example.com,newpassword123]"
      exit 1
    end

    user = User.find_by(email: email)
    
    if user.nil?
      puts "User not found: #{email}"
      exit 1
    end

    user.password = new_password
    user.password_confirmation = new_password
    
    if user.save
      puts "Password reset successfully for #{email}"
      puts "New password: #{new_password}"
    else
      puts "Failed to reset password:"
      puts user.errors.full_messages.join("\n")
      exit 1
    end
  end
end
