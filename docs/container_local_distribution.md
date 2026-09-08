# コンテナ版ローカル配布メモ

この構成は、Django と Nakama だけを Docker Compose で起動し、Godot の Windows exe は通常のデスクトップアプリとして起動する。

## 友人のPCに必要なもの

- Docker Desktop

Python、Node.js、Godot Editor は通常起動には不要。

## 渡すもの

- `docker-compose.yml`
- `team_h/`
- `nakama/`
- `build/2Dmetaverse.exe`
- `build/2Dmetaverse.pck`
- `tools/start_container_metaverse.bat`
- `tools/start_container_metaverse.ps1`
- `tools/stop_container_metaverse.bat`
- `tools/stop_container_metaverse.ps1`

`AWS/`、`venv/`、`.codex-tmp/`、`build/*.TMP` は渡さない。

## 起動

Docker Desktop を起動してから、以下をダブルクリックする。

```text
tools/start_container_metaverse.bat
```

このスクリプトは次を行う。

1. Django コンテナをビルドする。
2. PostgreSQL、Nakama、Django を起動する。
3. Nakama と Django の応答を待つ。
4. `build/2Dmetaverse.exe` を起動する。

手動でサーバーだけ起動する場合:

```powershell
powershell -ExecutionPolicy Bypass -File tools\start_container_metaverse.ps1 -NoLaunch
```

## 停止

```text
tools/stop_container_metaverse.bat
```

手動で止める場合:

```powershell
docker compose down
```

## URL

- Django: `http://127.0.0.1:8000`
- Nakama API: `http://127.0.0.1:7350`
- Nakama Console: `http://127.0.0.1:7351`
- Nakama Console login: `admin` / `password`

## 注意

この構成は1台のPC内で動かすためのもの。Godot は `127.0.0.1` の Django と Nakama に接続する。

すでに旧 `nakama/docker-compose.yml` のコンテナが起動している場合、`7350` または `7351` のポートが衝突する。その時は旧Nakamaを止めてから起動する。

```powershell
cd nakama
docker compose down
```
