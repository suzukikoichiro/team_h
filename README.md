# 2D Metaverse 共有用リポジトリ

Godot 4.5 のWindowsクライアント、Django、NakamaとDocker起動設定をまとめたソース一式です。
2026-09-08時点の作業ファイルを取り込んだ独立リポジトリです。元の2つのリポジトリの履歴やローカル設定は含みません。
今後の共同開発はこのフォルダで行ってください。元フォルダの変更は自動では反映されません。

## 構成

- `2-dmetaverse/`: Godotプロジェクト、素材、Nakamaアドオン
- `team_h/`: Djangoアプリ、マイグレーション、Dockerfile、Python依存定義
- `nakama/`: ローカルサーバー設定
- `tools/`: 起動・停止・Windowsエクスポートスクリプト
- `docker-compose.yml`: Django、Nakama、PostgreSQLの起動設定
- `.env.example`: メール送信設定のひな型

DB、登録済みアカウント、アップロードデータ、実際の.env、Godot本体、ビルド済みexe/pck、仮想環境は含みません。
既存のdocsには以前の機能や配布方式の記述もあります。初回取得はこのREADMEを参照してください。

## 受け取り方

### GitHubで共有する場合

所有者がGitHub上に空のリポジトリを作成します。READMEや.gitignoreはGitHub側で追加しません。
以下のOWNERを所有者名に置き換え、共有用フォルダで実行します。

```powershell
git remote add origin https://github.com/OWNER/metaverse-shared.git
git push -u origin main
```

非公開リポジトリの場合は共同作業者を招待し、受け取る人が招待を承認してから自分のGitHubアカウントで認証します。
パスワードやトークンをURLに埋め込まないでください。

受け取る人はGitをインストールし、保存先の親フォルダで実行します。

```powershell
git clone --branch main https://github.com/OWNER/metaverse-shared.git
cd metaverse-shared
```

更新を受け取るときは、自分の作業をコミットまたは退避したうえで実行します。

```powershell
git switch main
git pull --ff-only origin main
```

### GitHubを使わずbundleで渡す場合

所有者が作成した `metaverse-shared.bundle` をUSBやファイル共有で渡します。
受け取る人はbundleを置いたフォルダで実行します。

```powershell
git clone --branch main ./metaverse-shared.bundle metaverse-shared
cd metaverse-shared
```

bundleは作成時点のスナップショットです。GitHub公開後に更新を受け取る場合は接続先を変更します。

```powershell
git remote set-url origin https://github.com/OWNER/metaverse-shared.git
git pull --ff-only origin main
```

## 初回起動（Windows）

1. Docker Desktopをインストールして起動します。
2. Godot **4.5 stable（標準版）** を用意します。exeへのエクスポートには同じ4.5のエクスポートテンプレートも必要です。
3. リポジトリのルートで以下を実行し、作成した.envに送信用Gmailアドレスとアプリパスワードを設定します。

```powershell
Copy-Item .env.example .env
notepad .env
docker compose up -d --build
docker compose ps
```

メールOTP認証があるため、学校登録や管理者等の認証にはメール送信設定が必要です。.envはGitに登録されません。
初回はイメージとPython依存関係をダウンロードします。PythonはDocker内に入るためPC本体へのインストールは不要です。
起動時にDjangoのマイグレーションが実行され、空のDBが作成されます。

4. `http://127.0.0.1:8000/` を開き、学校登録からアカウントを作成します。
5. Godotで `2-dmetaverse/project.godot` をインポートし、初回素材読み込み後にF6ではなく **F5** でプロジェクトを実行します。

Windows exeを生成する場合はGodot本体の場所を実際のパスへ変更します。

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\export_windows_desktop.ps1 -GodotPath "C:\Tools\Godot\Godot_v4.5-stable_win64_console.exe"
.\tools\start_container_metaverse.bat
```

ビルド済みアプリを別途渡された場合はexeとpckを両方 `build/` に置けば、Godotをインストールせず起動スクリプトを利用できます。
停止は `tools/stop_container_metaverse.bat` または `docker compose down` です。

この構成では各PCが自分のローカルサーバーへ接続します。別PCの人と同じ空間へ入るには共通サーバーと接続先の設定が別途必要です。
ポート8000、7350、7351が使用中の場合は既存のサーバーを確認してください。

## 参照した公式資料

- [GitHub: リポジトリのクローン](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository)
- [Git: bundle](https://git-scm.com/docs/git-bundle)
- [Git: pull](https://git-scm.com/docs/git-pull)
- [Godot 4.5: エクスポート](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_projects.html)
