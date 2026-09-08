# 2D Metaverse 共有用リポジトリ

Godot 4.5 のWindowsクライアント、Django、NakamaとDocker起動設定をまとめたソース一式です。
2026-09-08時点の作業ファイルを取り込み、既存のGitHubリポジトリ `suzukikoichiro/team_h` の履歴を引き継いでいます。ローカルのGit認証設定は含みません。
今後の共同開発はこのフォルダで行ってください。元フォルダの変更は自動では反映されません。

## 構成

- `2-dmetaverse/`: Godotプロジェクト、素材、Nakamaアドオン
- `team_h/`: Djangoアプリ、マイグレーション、Dockerfile、Python依存定義
- `nakama/`: ローカルサーバー設定
- `tools/`: 起動・停止・Windowsエクスポートスクリプト
- `docker-compose.yml`: Django、Nakama、PostgreSQLの起動設定
- `.env.example`: メール送信設定のひな型
- `build/2Dmetaverse.exe` と `build/2Dmetaverse.pck`: Windows用の起動ファイル（両方必要）

現在のファイル一式にはDB、登録済みアカウント、アップロードデータ、実際の.env、Godot本体、仮想環境は含みません。既存のGit履歴に登録されていたファイルは過去の履歴に残ります。
既存のdocsには以前の機能や配布方式の記述もあります。初回取得はこのREADMEを参照してください。

## 受け取り方

### GitHubで共有する場合

共有先は [suzukikoichiro/team_h](https://github.com/suzukikoichiro/team_h) のmainです。

非公開リポジトリの場合は共同作業者を招待し、受け取る人が招待を承認してから自分のGitHubアカウントで認証します。
パスワードやトークンをURLに埋め込まないでください。

受け取る人はGitをインストールし、保存先の親フォルダで実行します。

```powershell
git clone --branch main https://github.com/suzukikoichiro/team_h.git metaverse-shared
cd metaverse-shared
```

更新を受け取るときは、自分の作業をコミットまたは退避したうえで実行します。

```powershell
git switch main
git pull --ff-only origin main
```

旧Django単体構成から更新する場合、Djangoのファイルはリポジトリ直下から `team_h/` に移っています。手動起動時の作業ディレクトリや既存のデプロイ設定も合わせて変更してください。新規起動はルートのDocker Composeを使用します。

### GitHubを使わずbundleで渡す場合

所有者が作成した `metaverse-shared.bundle` をUSBやファイル共有で渡します。
受け取る人はbundleを置いたフォルダで実行します。

```powershell
git clone --branch main ./metaverse-shared.bundle metaverse-shared
cd metaverse-shared
```

bundleは作成時点のスナップショットです。GitHub公開後に更新を受け取る場合は接続先を変更します。

```powershell
git remote set-url origin https://github.com/suzukikoichiro/team_h.git
git pull --ff-only origin main
```

## 初回起動（Windows）

1. Docker Desktopをインストールして起動します。
2. `build/2Dmetaverse.exe` と `build/2Dmetaverse.pck` があることを確認します。どちらもGitHubに同梱しています。通常起動にはGodotのインストールは不要です。
3. リポジトリのルートで以下を実行し、作成した.envに送信用Gmailアドレスとアプリパスワードを設定します。

```powershell
if (!(Test-Path .env)) { Copy-Item .env.example .env }
notepad .env
```

ここでメール設定を保存してメモ帳を閉じてから、次を実行します。実行場所は `tools/` の1つ上、`docker-compose.yml` と `.env.example` があるフォルダです。

```powershell
docker compose up -d --build
docker compose ps
```

メールOTP認証があるため、学校登録や管理者等の認証にはメール送信設定が必要です。.envはGitに登録されません。
初回はイメージとPython依存関係をダウンロードします。PythonはDocker内に入るためPC本体へのインストールは不要です。
起動時にDjangoのマイグレーションが実行され、空のDBが作成されます。

4. `http://127.0.0.1:8000/` を開き、学校登録からアカウントを作成します。
5. `tools/start_container_metaverse.bat` をダブルクリックすると、サーバーの起動確認後にGodot画面が開きます。PowerShellからはリポジトリのルートで次を実行します。

```powershell
.\tools\start_container_metaverse.bat
```

以前に取得して `build/` がない場合は、`git pull --ff-only origin main` で更新してください。GitHubのDownload ZIPで取得した場合は最新のZIPを別フォルダへ展開し、既存の.envを引き継いでください。

開発用にWindows exeを再生成する場合のみ、Godot **4.5 stable（標準版）** と同じ4.5のエクスポートテンプレートを用意します。Godotで `2-dmetaverse/project.godot` を開いて素材の読み込みを済ませ、以下のGodot本体の場所を実際のパスへ変更します。

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\export_windows_desktop.ps1 -GodotPath "C:\Tools\Godot\Godot_v4.5-stable_win64_console.exe"
.\tools\start_container_metaverse.bat
```

exeとpckは同じビルドで生成されたものをセットで使用してください。
停止は `tools/stop_container_metaverse.bat` または `docker compose down` です。

この構成では各PCが自分のローカルサーバーへ接続します。別PCの人と同じ空間へ入るには共通サーバーと接続先の設定が別途必要です。
ポート8000、7350、7351が使用中の場合は既存のサーバーを確認してください。

## 参照した公式資料

- [GitHub: リポジトリのクローン](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository)
- [Git: bundle](https://git-scm.com/docs/git-bundle)
- [Git: pull](https://git-scm.com/docs/git-pull)
- [Godot 4.5: エクスポート](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_projects.html)
