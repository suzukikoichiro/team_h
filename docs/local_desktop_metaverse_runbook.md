# ローカルWindows Desktopメタバース起動手順

## 1. 接続先の切り替え

Godot側の接続先はここだけを見る。

`C:\卒業制作\2-dmetaverse\scripts\app_config.gd`

ローカルで動かす時:

```gdscript
const MODE := MODE_LOCAL
```

将来ネット公開する時:

```gdscript
const MODE := MODE_PUBLIC
```

公開時は同じファイル内の `PUBLIC_DJANGO_API_BASE`、`PUBLIC_NAKAMA_HOST`、`PUBLIC_NAKAMA_SERVER_KEY` を本番値に変える。

## 2. DjangoとNakamaを起動

Godot Desktop版はログイン必須。学校ID、ユーザーID、パスワードはDjango側で作成済みの教職員/学生アカウントを使う。

Djangoを起動する場合:

```powershell
cd C:\卒業制作\team_h
C:\卒業制作\venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000
```

Godot設定、Nakama SDK、ローカル接続、チャット/移動イベント配送をまとめて確認する場合:

```powershell
powershell -ExecutionPolicy Bypass -File C:\卒業制作\tools\check_local_setup.ps1
```

簡単に起動確認だけする場合:

```powershell
powershell -ExecutionPolicy Bypass -File C:\卒業制作\tools\start_local_metaverse.ps1 -NoLaunch
```

Nakamaを起動して、エクスポート済みexeも起動する場合:

```powershell
powershell -ExecutionPolicy Bypass -File C:\卒業制作\tools\start_local_metaverse.ps1
```

NakamaのCustom認証だけ確認する場合:

```powershell
powershell -ExecutionPolicy Bypass -File C:\卒業制作\tools\check_local_nakama.ps1
```

NakamaのRealtimeチャット配送と移動イベント配送まで確認する場合:

```powershell
node C:\卒業制作\tools\check_nakama_realtime_chat.js
```

手動で起動する場合:

```powershell
cd C:\卒業制作\nakama
docker compose up -d
```

確認:

```powershell
docker compose ps
```

Nakama Console:

- `http://127.0.0.1:7351`
- `admin` / `password`

## 3. Godotを起動

Godot Editorで以下を開く。

`C:\卒業制作\2-dmetaverse`

起動するとログイン画面が出る。Djangoで作成済みの `学校ID`、`ユーザーID`、`パスワード` を入力する。

ログイン成功後、学校IDごとにNakamaのルームが分かれる。例:

```text
school-1-lobby
school-2-lobby
```

## 4. チャット確認

1. Nakamaを起動する。
2. Godotを2つ起動する、またはエディタ実行とエクスポートexeを同時に起動する。
3. メニューからチャットを開く。
4. 片方で送信したメッセージがもう片方に表示されることを確認する。

Windows Desktop版を2つ起動して確認する場合:

```powershell
powershell -ExecutionPolicy Bypass -File C:\卒業制作\tools\start_two_local_clients.ps1
```

ダブルクリックで起動する場合:

```text
C:\卒業制作\tools\start_two_local_clients.bat
```

ログを監視する場合:

```powershell
powershell -ExecutionPolicy Bypass -File C:\卒業制作\tools\tail_godot_log.ps1
```

チャットはNakamaのルームチャンネルを使う。移動同期はNakama Match、チャットはNakama Channelという分担。

Godotの出力ログに以下が出れば、Nakama接続とチャットチャンネル参加は成功。

```text
Created Nakama match:
```

または、2人目以降では以下。

```text
Joined existing Nakama match:
```

続けて以下が出れば、同じルームのチャットチャンネル参加も成功。

```text
Nakama connected match:
Nakama chat channel:
```

ローカルモードでもDjangoログインが必要。Djangoが起動していない場合、Godotはログイン画面から先へ進まない。

Windows Desktop版のGodotログは通常ここに出る。アプリを複数起動した時に混ざらないよう、起動ごとに別ファイルになる。

```text
%APPDATA%\Godot\app_userdata\2Dmetaverse\local_metaverse_プロセスID_時刻.log
%APPDATA%\Godot\app_userdata\2Dmetaverse\latest_log_path.txt
```

直近に起動したアプリのログを見る場合:

```powershell
powershell -ExecutionPolicy Bypass -File C:\卒業制作\tools\tail_godot_log.ps1
```

ログ内に以下が出れば接続成功。

```text
Nakama connected match=
Chat realtime connected
```

チャット送受信時は以下のようなログが出る。

```text
send chat message id=
received channel chat id=
```

移動同期の保険経路を受けた時は以下が出る。

```text
received channel move user=
```

## 5. Windows Desktop出力

Godot Editor:

1. `Project > Export`
2. `Windows Desktop`
3. Export先が `C:\卒業制作\build\2Dmetaverse.exe` になっていることを確認
4. `Export Project`

PowerShellから出す場合はGodot本体のexeパスを指定する。

```powershell
powershell -ExecutionPolicy Bypass -File C:\卒業制作\tools\export_windows_desktop.ps1 -GodotPath "C:\path\to\Godot.exe"
```

コマンドで出す場合:

```powershell
cd C:\卒業制作\2-dmetaverse
godot --export-release "Windows Desktop" C:\卒業制作\build\2Dmetaverse.exe
```
