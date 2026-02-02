# テスト環境でのログイン方法

## テスト環境でログインする方法

### 1. テスト用シードデータを投入（オプション）

テストデータベースにシードデータを投入する場合：

```bash
# テスト環境でシードを実行
RAILS_ENV=test rails db:seed:test

# または直接実行
RAILS_ENV=test rails runner db/seeds_test.rb
```

### 2. テストコードでログイン

`spec/support/auth_helpers.rb` にヘルパーメソッドを用意しました。

#### 基本的な使い方

```ruby
# RSpecのテストファイル内で

# 内部管理者としてログイン
login_as_internal_admin

# 会社管理者としてログイン
login_as_company_admin

# 一般ユーザーとしてログイン
login_as_normal_user

# 特定のユーザーとしてログイン
user = create(:user, :with_profile, 
  company: company, 
  role: :company_admin,
  member_status: :active
)
login_as(user)

# メールアドレスでログイン（ユーザーが存在しない場合は自動作成）
login_as("test@example.com")
```

#### 実際のテスト例

```ruby
# spec/requests/dashboard_spec.rb
RSpec.describe "Dashboard", type: :request do
  describe "GET /dashboard" do
    it "内部管理者としてアクセスできる" do
      login_as_internal_admin
      get dashboard_path
      expect(response).to have_http_status(:success)
    end

    it "会社管理者としてアクセスできる" do
      login_as_company_admin
      get dashboard_path
      expect(response).to have_http_status(:success)
    end

    it "一般ユーザーとしてアクセスできる" do
      login_as_normal_user
      get dashboard_path
      expect(response).to have_http_status(:success)
    end
  end
end
```

### 3. テスト用のデフォルトアカウント

以下のアカウントがテスト用に用意されています（パスワード: `password123456`）：

- **Internal Admin**: `admin@system.local`
- **Company A Admin**: `admin@acme.com`
- **Company A User**: `user@acme.com`
- **Company B Admin**: `admin@beta-ind.com`

### 4. 手動でテスト環境にログインする場合

Railsコンソールでテスト環境を起動：

```bash
RAILS_ENV=test rails console
```

```ruby
# ユーザーを作成してログイン情報を確認
user = User.find_by(email: "admin@system.local")
puts "Email: #{user.email}"
puts "Password: password123456"  # シードで設定されたパスワード

# パスワードを検証
user.valid_password?("password123456")  # => true
```

### 5. システムテスト（Capybara）でログイン

```ruby
# spec/system/dashboard_spec.rb
RSpec.describe "Dashboard", type: :system do
  it "ログインしてダッシュボードにアクセスできる" do
    login_as_internal_admin
    
    visit dashboard_path
    expect(page).to have_content("ダッシュボード")
  end
end
```

## 注意事項

- テスト環境では、各テストの前にデータベースがクリーンアップされます（DatabaseCleaner）
- テスト用のユーザーは各テストで作成するか、`before`ブロックで作成してください
- `login_as` ヘルパーは自動的にユーザーを作成するので、存在しないユーザーでもログインできます
