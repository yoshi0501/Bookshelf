# frozen_string_literal: true

# Password Checker Utility
# Usage in Rails console:
#   PasswordChecker.show_user("user@example.com")
#   PasswordChecker.list_all
#   PasswordChecker.reset_password("user@example.com", "newpassword123")

class PasswordChecker
  def self.show_user(email)
    user = User.find_by(email: email)
    
    if user.nil?
      puts "User not found: #{email}"
      return nil
    end

    puts "\n=== User Information ==="
    puts "Email: #{user.email}"
    puts "ID: #{user.id}"
    puts "Created: #{user.created_at}"
    puts "Password Changed At: #{user.password_changed_at || 'Never'}"
    puts "\n=== Password Hash (encrypted_password) ==="
    puts user.encrypted_password
    puts "\n=== Password Status ==="
    begin
      puts "Password Expired: #{user.password_expired?}"
    rescue
      puts "Password Expired: N/A"
    end
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
    
    user
  end

  def self.list_all
    users = User.includes(:user_profile).order(:email)
    
    puts "\n=== All Users ==="
    printf "%-40s %-20s %-30s %-15s\n", "Email", "Password Changed", "Company", "Status"
    puts "-" * 105
    
    users.each do |user|
      password_changed = user.password_changed_at&.strftime("%Y-%m-%d %H:%M") || "Never"
      company = user.user_profile&.company&.name || "N/A"
      status = user.user_profile&.member_status || "N/A"
      
      printf "%-40s %-20s %-30s %-15s\n", user.email, password_changed, company, status
    end
    
    puts "\nTotal: #{users.count} users"
    users
  end

  def self.reset_password(email, new_password)
    user = User.find_by(email: email)
    
    if user.nil?
      puts "User not found: #{email}"
      return false
    end

    user.password = new_password
    user.password_confirmation = new_password
    
    if user.save
      puts "Password reset successfully for #{email}"
      puts "New password: #{new_password}"
      true
    else
      puts "Failed to reset password:"
      puts user.errors.full_messages.join("\n")
      false
    end
  end

  def self.verify_password(email, password)
    user = User.find_by(email: email)
    
    if user.nil?
      puts "User not found: #{email}"
      return false
    end

    if user.valid_password?(password)
      puts "Password is CORRECT for #{email}"
      true
    else
      puts "Password is INCORRECT for #{email}"
      false
    end
  end
end
