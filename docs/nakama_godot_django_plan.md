# Django + Godot Windows Desktop + Nakama 移行手順

## 1. 役割分担

- Django: 学校、管理者、教員、生徒、クラス情報の正本。
- Nakama: メタバース内のリアルタイム通信、入室、Presence、チャット、位置同期。
- Godot Windows Desktop: 生徒と教員が使う2Dメタバースアプリ。

## 2. こちらで作ったもの

- `team_h/core/views/manage_api_views.py`
  - `/api/nakama_session/` を追加。
  - Djangoログイン中のユーザーからNakama Custom Auth用の `custom_id`、ユーザー名、学校ID、クラスID、ルーム名を返す。
- `team_h/team_h/settings.py`
  - `NAKAMA_SCHEME`、`NAKAMA_HOST`、`NAKAMA_PORT`、`NAKAMA_SERVER_KEY` を追加。
- `2-dmetaverse/scenes/network.gd`
  - 既存の `Network.connect_world()` と `Network.send_move()` を残したままNakama対応。
  - Nakama SDK未導入、または接続失敗時は今までのDjango WebSocketへフォールバック。
- `nakama/docker-compose.yml`
  - ローカル開発用Nakama + PostgreSQL。
- `nakama/local.yml`
  - ローカルNakama設定。

## 3. Nakamaを起動する

Docker Desktopを起動してから、PowerShellで実行する。

```powershell
cd C:\卒業制作\nakama
docker compose up
```

Nakama Console:

- URL: `http://127.0.0.1:7351`
- ID: `admin`
- Password: `password`

## 4. Djangoを起動する

別のPowerShellで実行する。

```powershell
cd C:\卒業制作\team_h
..\venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000
```

ngrokを使う場合は、Godotの `ApiClient.API_BASE` を今まで通りngrok URLにする。ローカルで直接試すなら `http://127.0.0.1:8000` に変える。

## 5. GodotにNakama SDKを入れる

Godot Asset Library、またはHeroic LabsのGitHub Releasesから Godot 4 用Nakama SDKを入れる。

入れた後、Godot Editorで:

1. `Project > Project Settings > Autoload`
2. `addons/com.heroiclabs.nakama/Nakama.gd` を追加
3. Autoload名を `Nakama` にする

これで `Network.gd` がNakamaを使うようになる。

## 6. GodotをWindows Desktopで出力する

すでに `export_presets.cfg` に `Windows Desktop` プリセットがある。

Godot Editorから:

1. `Project > Export`
2. `Windows Desktop`
3. 出力先を学校配布用フォルダに変更
4. `Export Project`

コマンドで出す場合:

```powershell
cd C:\卒業制作\2-dmetaverse
godot --export-release "Windows Desktop" C:\卒業制作\build\2Dmetaverse.exe
```

## 7. 最初の動作確認

1. Djangoに学校、クラス、生徒を登録。
2. Nakamaを起動。
3. Djangoにログイン。
4. Godotアプリを起動。
5. 2台または2ウィンドウで同じクラスのユーザーとして入室。
6. 片方を動かして、もう片方に位置が反映されることを確認。

## 8. 次に作るとよいもの

- NakamaのPresenceから入室者一覧を表示。
- クラスごとに固定ルームへ入室。
- Nakama Chatで教室内チャットを移行。
- 管理者画面に「現在オンラインの生徒」を表示。
- 重要な操作だけDjangoに履歴保存。
