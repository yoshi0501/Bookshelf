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

  desc "診断: メーカー用户がログインできない理由を表示（EMAIL=xxx PASSWORD=xxx で指定。zsh ではクォート推奨）"
  task :diagnose_maker, [:email] => :environment do |_t, args|
    email = (ENV["EMAIL"].presence || args[:email] || "maker-m01@platform.example.com").to_s.strip
    password = ENV["PASSWORD"].presence || "SeedPass1"
    user = User.find_by(email: email)

    puts "\n=== メーカーログイン診断: #{email} ===\n"
    if user.nil?
      puts "【要因】ユーザーが存在しません（このメールの User が DB にいません）"
      puts "   → bin/rails users:fix_maker または RESET=1 bin/rails db:seed"
      exit 1
    end

    reasons = []
    puts "User ID: #{user.id}"

    # 1) パスワード（Devise が最初にチェックする）
    pw_ok = user.valid_password?(password)
    puts "valid_password?(#{password.inspect}): #{pw_ok ? 'OK' : '❌ 不一致'}"
    reasons << "パスワードが一致しません（入力: #{password.inspect}）" unless pw_ok

    puts "confirmed_at: #{user.confirmed_at.present? ? 'OK' : '❌ nil（未確認）'}"
    reasons << "confirmed_at が nil" unless user.confirmed_at.present?

    puts "locked_at: #{user.locked_at.present? ? "❌ ロック中 (#{user.locked_at})" : 'OK'}"
    reasons << "アカウントがロックされています" if user.locked_at.present?

    puts "failed_attempts: #{user.failed_attempts}"
    puts "password_changed_at: #{user.password_changed_at.present? ? 'OK' : '⚠️ nil'}"
    reasons << "password_changed_at が nil" unless user.password_changed_at.present?

    if user.user_profile.nil?
      puts "user_profile: ❌ なし"
      reasons << "user_profile がありません"
    else
      p = user.user_profile
      puts "user_profile: あり (id=#{p.id})"
      puts "  member_status: #{p.member_status} #{p.active? ? 'OK' : '❌ active ではない'}"
      reasons << "member_status が active ではない" unless p.active?
      puts "  manufacturer_id: #{p.manufacturer_id.present? ? "OK (#{p.manufacturer_id})" : '❌ 未設定'}"
      reasons << "manufacturer_id が未設定" if p.manufacturer_id.blank?
    end

    can_auth = user.active_for_authentication?
    puts "\nactive_for_authentication?: #{can_auth ? 'true' : 'false'}"

    puts "\n--- 要因のまとめ ---"
    if reasons.any?
      puts "❌ ログインできない要因（上記のいずれか）:"
      reasons.each { |r| puts "  ・#{r}" }
      puts "\n→ 修正: EMAIL=#{email} bin/rails users:fix_maker （または users:reset_maker_password）"
    else
      puts "✅ DB 上はログイン条件を満たしています。"
      puts "   まだ入れない場合: ブラウザのキャッシュ削除・シークレット窓、パスワードのコピペ（SeedPass1）、サーバー再起動を試してください。"
    end
    puts ""
  end

  desc "メーカー用户をログイン可能な状態に修正（EMAIL=maker-m04@platform.example.com で指定。未指定なら全メーカー用户）"
  task fix_maker: :environment do
    seed_password = "SeedPass1"
    target_email = ENV["EMAIL"].to_s.strip.presence

    if target_email.present?
      users = User.where(email: target_email).to_a
      puts "対象: #{target_email} (#{users.size}件)"
    else
      # Manufacturer からメール一覧を組み立てて検索
      emails = []
      manufacturers = []
      if ActiveRecord::Base.connection.table_exists?("manufacturers")
        manufacturers = Manufacturer.ordered_by_code.to_a
        manufacturers.each do |m|
          safe = m.code.to_s.downcase.gsub(/[^a-z0-9]/, "-")
          emails << "maker-#{safe}@platform.example.com"
        end
      end
      users = emails.any? ? User.where(email: emails).to_a : []
      puts "対象: メーカー用户（#{emails.any? ? emails.join(", ") : "メーカー未登録"}） (#{users.size}件)"

      # メーカー（Manufacturer）が0件なら先にプラットフォーム共通メーカーを自動作成
      if manufacturers.empty? && ActiveRecord::Base.connection.table_exists?("manufacturers")
        puts "メーカー（Manufacturer）が0件のため、M01〜M04 を作成します..."
        %w[M01 M02 M03 M04].each do |code|
          m = Manufacturer.find_or_create_by!(code: code) do |mc|
            mc.name = "共通メーカー#{code}"
            mc.email = "ship-#{code.downcase}@platform.example.com"
            mc.phone = "03-1234-#{code[-1]}000"
            mc.is_active = true
          end
          manufacturers << m
        end
        emails = manufacturers.map { |m| "maker-#{m.code.to_s.downcase.gsub(/[^a-z0-9]/, '-')}@platform.example.com" }
      end

      # 0件ならメーカー用户をここで作成（RESET=1 seed 不要）
      if users.empty? && manufacturers.any? && UserProfile.column_names.include?("manufacturer_id")
        puts "メーカー用户が存在しないため、作成します..."
        manufacturers.each do |manufacturer|
          safe_code = manufacturer.code.to_s.downcase.gsub(/[^a-z0-9]/, "-")
          maker_email = "maker-#{safe_code}@platform.example.com"
          maker_user = User.find_or_initialize_by(email: maker_email)
          maker_user.assign_attributes(
            password: seed_password,
            password_confirmation: seed_password,
            confirmed_at: Time.current,
            password_changed_at: Time.current,
            failed_attempts: 0,
            locked_at: nil,
            unlock_token: nil
          )
          maker_user.save!
          maker_user.user_profile&.destroy
          maker_user.create_user_profile!(
            company: nil,
            manufacturer: manufacturer,
            name: "#{manufacturer.name} 担当",
            role: :normal,
            member_status: :active
          )
          puts "  #{maker_email} を作成しました。"
        end
        users = User.where(email: emails).to_a
      end
    end

    if users.empty?
      puts "ユーザーが見つかりません。"
      puts ""

      if target_email.present?
        # EMAIL 指定時: そのメールの User が存在しない
        puts "  【原因】EMAIL で指定した「#{target_email}」の User がこの DB に存在しません。"
        puts "    → メーカー用户を自動作成するには、EMAIL を付けずに bin/rails users:fix_maker を実行してください。"
        puts "    → メールアドレス typo でないかも確認してください。"
      else
        # 全メーカー用户対象時: 原因1〜3 を表示
        has_manufacturers_table = ActiveRecord::Base.connection.table_exists?("manufacturers")
        has_manufacturer_id_col = UserProfile.column_names.include?("manufacturer_id")

        unless has_manufacturers_table
          puts "  【原因1】manufacturers テーブルがありません。"
          puts "    → メーカー用户を作るにはこのテーブルが必要です。"
        end
        unless has_manufacturer_id_col
          puts "  【原因2】user_profiles.manufacturer_id カラムがありません。"
          puts "    → メーカー用户は「どのメーカーか」を UserProfile の manufacturer_id で持つため、"
          puts "      このカラムが無いと作成できません。seed も fix_maker も同じ理由でスキップしています。"
        end
        if has_manufacturers_table && has_manufacturer_id_col && Manufacturer.count.zero?
          puts "  【原因3】メーカー（Manufacturer）が0件のため自動作成を試みましたが、User が作成されていません。"
        end

        puts ""
        puts "  ★ 対処: まず bin/rails db:migrate を実行してから、再度 bin/rails users:fix_maker を実行してください。"
        puts "     （マイグレーションで manufacturers テーブルと user_profiles.manufacturer_id が追加されます）"
      end
      exit 1
    end

    users.each do |user|
      # メールからメーカーコード取得（maker-m04@... → M04）
      code = user.email.match(/\Amaker-([a-z0-9-]+)@platform\.example\.com\z/i)&.[](1)&.tr("-", "")&.upcase
      code = "M01" if code.blank?
      manufacturer = Manufacturer.find_by("UPPER(REPLACE(code, '-', '')) = ?", code) || Manufacturer.find_by(code: code) || Manufacturer.ordered_by_code.first

      # ロック・確認・パスワード期限・パスワードを update_columns で確実に反映（コールバックに依存しない）
      encrypted = Devise::Encryptor.digest(User, seed_password)
      user.update_columns(
        encrypted_password: encrypted,
        confirmed_at: Time.current,
        password_changed_at: Time.current,
        failed_attempts: 0,
        locked_at: nil,
        unlock_token: nil,
        updated_at: Time.current
      )

      if user.user_profile.nil?
        if manufacturer
          user.create_user_profile!(
            company: nil,
            manufacturer: manufacturer,
            name: "#{manufacturer.name} 担当",
            role: :normal,
            member_status: :active
          )
          puts "  #{user.email}: プロファイル作成 OK (メーカー: #{manufacturer.code})"
        else
          puts "  #{user.email}: スキップ（メーカーが存在しません）"
        end
      else
        attrs = { member_status: :active, company_id: nil }
        attrs[:manufacturer_id] = manufacturer.id if manufacturer
        user.user_profile.update!(attrs)
        puts "  #{user.email}: プロファイル修正 OK (member_status: active, manufacturer: #{manufacturer&.code})"
      end

      user.reload
      pw_ok = user.valid_password?(seed_password)
      auth_ok = user.active_for_authentication?
      puts "  #{user.email}: パスワード一致=#{pw_ok}, 認証許可=#{auth_ok}#{auth_ok ? "" : " (user_profile: #{user.user_profile&.member_status.inspect})"}"
    end
    puts "完了。パスワード: #{seed_password} でログインしてください。"
  end

  desc "メーカー用户のパスワードを SeedPass1 にリセットして検証（EMAIL=maker-m04@platform.example.com）"
  task reset_maker_password: :environment do
    email = ENV["EMAIL"].to_s.strip.presence || "maker-m04@platform.example.com"
    pw = "SeedPass1"
    user = User.find_by(email: email)
    unless user
      puts "ユーザーが見つかりません: #{email}"
      exit 1
    end
    encrypted = Devise::Encryptor.digest(User, pw)
    user.update_columns(encrypted_password: encrypted, confirmed_at: Time.current, password_changed_at: Time.current, failed_attempts: 0, locked_at: nil, unlock_token: nil, updated_at: Time.current)
    user.reload
    puts "パスワードをリセットしました。"
    puts "  valid_password?(SeedPass1): #{user.valid_password?(pw)}"
    puts "  active_for_authentication?: #{user.active_for_authentication?}"
    puts "  user_profile.member_status: #{user.user_profile&.member_status}"
    puts "→ 上記が true/active なら #{email} / #{pw} でログインできるはずです。"
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
