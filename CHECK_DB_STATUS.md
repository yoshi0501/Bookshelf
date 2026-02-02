# データベース状態確認ガイド

## PostgreSQLの状態

PostgreSQL@16は起動しています。`postgresql@14`のエラーは無視して問題ありません。

## データベース接続を確認

以下のコマンドでデータベースの状態を確認できます：

```bash
cd /Users/fukuyama/Desktop/ecoowl/Bookshelf

# データベースに接続できるか確認
rails db:version

# ユーザー数を確認
rails runner "puts 'Users: ' + User.count.to_s; puts 'Companies: ' + Company.count.to_s"
```

## シードデータを投入

データベースが空の場合（User.countが0の場合）、シードデータを投入してください：

```bash
rails db:seed
```

## 確認方法

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
```
