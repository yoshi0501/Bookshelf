# データベースセットアップガイド

## データベースにユーザーデータを投入する方法

### 1. PostgreSQLが起動していることを確認

```bash
# PostgreSQLの状態を確認（macOSの場合）
brew services list | grep postgresql

# PostgreSQLを起動（必要に応じて）
brew services start postgresql
```

### 2. データベースを作成・マイグレーション

```bash
cd /Users/fukuyama/Desktop/ecoowl/Bookshelf
rails db:create
rails db:migrate
```

### 3. シードデータを投入

```bash
rails db:seed
```

これで以下のテストユーザーが作成されます：

- **Internal Admin**: `admin@system.local` / `password123456`
- **Company A Admin**: `admin@acme.com` / `password123456`
- **Company A User**: `user@acme.com` / `password123456`
- **Company B Admin**: `admin@beta-ind.com` / `password123456`

### 4. ユーザーが作成されたか確認

Railsコンソールで確認：

```bash
rails console
```

```ruby
# ユーザー数を確認
User.count

# すべてのユーザーを表示
PasswordChecker.list_all

# 特定のユーザーを確認
PasswordChecker.show_user("admin@system.local")

# パスワードを検証
PasswordChecker.verify_password("admin@system.local", "password123456")
```

## トラブルシューティング

### PostgreSQLに接続できない場合

1. PostgreSQLが起動しているか確認
2. `config/database.yml` の設定を確認
3. データベースが作成されているか確認: `rails db:create`

### シードデータが投入できない場合

- エラーメッセージを確認
- 既存のデータと競合していないか確認
- `rails db:reset` でデータベースをリセットしてから再度シードを実行
