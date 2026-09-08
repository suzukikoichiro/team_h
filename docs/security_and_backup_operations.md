# セキュリティ・バックアップ運用手順

## バックアップ

1. 管理者で学校管理ポータルへログインする。
2. 「バックアップ管理」から「今すぐバックアップを作成」を選ぶ。
3. 作成日時、レコード数、SHA-256の先頭値を確認し、必要に応じてダウンロードして安全な保管先へ移す。
4. 復元時は対象バックアップの確認欄に `復元する` と入力する。復元前の現在状態は自動で別バックアップとして保存される。

バックアップは学校単位で作成され、学校ID・形式バージョン・SHA-256を照合してから復元する。他校のアーカイブは一覧・ダウンロード・復元のいずれもできない。

## 本番環境の設定

本番起動前に、次の環境変数を設定する。

```text
DJANGO_SECRET_KEY=<ランダムな十分に長い秘密鍵>
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=<公開するホスト名>
DJANGO_SECURE_SSL_REDIRECT=1
DJANGO_EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
DJANGO_EMAIL_HOST=<SMTPサーバー名>
DJANGO_EMAIL_PORT=587
DJANGO_EMAIL_HOST_USER=<SMTPユーザー名>
DJANGO_EMAIL_HOST_PASSWORD=<SMTPパスワード>
DJANGO_EMAIL_USE_TLS=1
DJANGO_DEFAULT_FROM_EMAIL=<送信元メールアドレス>
```

`DEBUG=0` のとき、セッションCookieとCSRF CookieはHTTPS専用になる。秘密鍵やパスワード、バックアップファイルをGit等の公開場所へ置かない。

管理者・教職員の登録、ログイン、メールアドレス変更では6桁のワンタイム認証コードを送信する。コードの有効期限は10分、入力上限は5回、再送信間隔は60秒。Django単体起動時の既定値はコンソール送信、Docker ComposeはGmail SMTP設定である。本番では上記SMTP設定を必ず指定し、コンソール送信のまま運用しない。

### GmailをローカルDocker環境で使う

Googleアカウントの2段階認証を有効にし、Googleアカウントの「アプリ パスワード」からメール用の16文字のパスワードを発行する。プロジェクト直下の `.env.example` を `.env` にコピーし、送信元Gmailアドレスとアプリパスワードを設定する。通常のGoogleアカウントパスワードは使用しない。

```powershell
Copy-Item .env.example .env
# .env を編集後
docker compose up -d --force-recreate django
docker compose exec -T django python manage.py shell -c "from django.core.mail import send_mail; print(send_mail('2Dメタバース SMTP確認', 'Gmail SMTPの送信確認です。', None, ['受信確認用メールアドレス'], fail_silently=False))"
```

`.env` は秘密情報を含むため共有・コミットしない。送信確認結果が `1` ならSMTPサーバーがメールを受け付けている。

## 確認コマンド

```powershell
cd C:\卒業制作\team_h
..\venv\Scripts\python.exe .\manage.py check
..\venv\Scripts\python.exe .\manage.py test core.tests.AuthenticationSecurityTests
..\venv\Scripts\python.exe .\manage.py test core.tests.BackupTests
..\venv\Scripts\python.exe .\manage.py test core.tests.DataIsolationTests
```
