# worklog

日々の作業記録をCLIで管理し、Discordに投稿するツール。

タイムライン形式で時間ブロックごとにタスクを記録し、振り返り・翌日のTODOを含めた日報を生成する。

## セットアップ

### 1. リポジトリをclone

```bash
git clone git@github.com:<your-username>/worklog.git ~/projects/worklog
```

### 2. PATHを通す

`.zshrc`（または `.bashrc`）に追記:

```bash
export PATH="$HOME/projects/worklog/bin:$PATH"
```

反映:

```bash
source ~/.zshrc
```

### 3. Discord Webhook URLを設定

Discordのチャンネル設定 → 連携サービス → ウェブフック から URLを取得し、`.zshrc` に追記:

```bash
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/xxxx/yyyy"
```

### 4. 動作確認

```bash
worklog help
```

## 使い方

### 作業の記録（日中こまめに）

```bash
# タスクを追加（時間ブロックは自動判定）
worklog add "MRNX: 開発: SolidQueueの停止処理"

# 直前のタスクにメモを追加
worklog note "Logの量確認"
worklog note "開発/STG: 拡張モニタリングOFF"

# さらに深いインデントのメモ
worklog note -d 2 "昨日の対応と合わせてかなり減ったはず"
```

### 終業時

```bash
# 振り返りを追加
worklog retro "MRNX: QuickSightに関して要確認"

# 明日のやることを追加
worklog todo "MRNX: QuickSuite調整 / IMEIチェック機能"

# プレビュー確認
worklog review

# Discordに投稿
worklog post
```

### その他

```bash
# エディタで直接編集（細かい修正に）
worklog edit

# 投稿プレビュー（送信しない）
worklog post --dry-run

# リマインド設定のヘルプ
worklog remind
```

## 出力例

```
2026/03/10(火)
タイムライン

10:00 〜
* SEJ: 障害対応時の情報の更新
* MEIJI: MTG調整
* 定例(火)
* MRNX: 開発: SolidQueueの停止処理
12:00 〜
* MRNX: 設定調整
   * Logの量確認
   * 開発/STG: 拡張モニタリングOFF

本日の業務振り返り

* MRNX: QuickSightに関して要確認

明日のやること

* MRNX: QuickSuite調整 / IMEIチェック機能
```

## 環境変数

| 変数名 | デフォルト | 説明 |
|---|---|---|
| `DISCORD_WEBHOOK_URL` | (なし) | Discord Webhook URL（`post` 時に必須） |
| `WORKLOG_DIR` | `~/worklogs` | ログファイルの保存先 |
| `WORKLOG_BLOCK_INTERVAL` | `2` | 時間ブロックの間隔（時間） |
| `WORKLOG_START_HOUR` | `10` | 業務開始時刻（時） |
| `EDITOR` | `vim` | `worklog edit` で使うエディタ |

## リマインド設定（任意）

`crontab -e` で以下を追加すると、2時間ごとに記録を促す通知が届く:

```cron
# macOS
0 10,12,14,16,18 * * 1-5 osascript -e 'display notification "作業ログを記録しましょう！" with title "worklog"'

# 終業時に自動投稿（19:00）
0 19 * * 1-5 $HOME/projects/worklog/bin/worklog post
```

## 依存

- Ruby（標準ライブラリのみ、gem不要）
