# Bookshelf プロジェクトルール（Cursor / AI 用）

このプロジェクトで AI に依頼するときの前提です。チャットで `@RULE.md` を指定するか、プロジェクトを開いた状態で参照されます。

---

## 共通

- **返答は日本語で行う。**
- プロジェクトの前提は `docs/コンセプト.md` を参照する。クローズドリサイクル・CO2 見える化・B2B 発注管理が中核。

## 技術

- Ruby on Rails 7、PostgreSQL。マルチテナント（Company 単位でデータ分離）。
- 認証: Devise。認可: Pundit（Policy で company スコープを必ずかける）。
- センター = Customer（請求先は `is_billing_center: true`、受注拠点は `billing_center_id` で紐づく）。

## コード

- 新規機能は既存の Policy・スコープに合わせる。会社・センターをまたいだデータ参照をしない。
- 日本語メッセージは `config/locales/ja.yml` に追加。キーは既存のネストに合わせる。
- パスワード: 8 文字以上・英数字混在。`PasswordValidations` concern と devise-security で検証。

## ドキュメント

- 契約・セキュリティ・パスワード要件などの回答は `docs/` に Markdown で保存済み。必要なら参照する。
