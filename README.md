# worklog

日々の作業記録をCLIで管理し、Discordに貼り付けて投稿するツール。

タイムライン形式で時間ブロックごとにタスクを記録し、振り返り・翌日のTODOを含めた日報を生成する。

## セットアップ

### 1. リポジトリをclone

```bash
git clone git@github.com:<your-username>/worklog.git ~/environment/worklog
```

### 2. 実行スクリプトを作成する

```bash
mkdir -p ~/environment/worklog/bin
cat > ~/environment/worklog/bin/worklog << 'EOF'
#!/usr/bin/env ruby
load File.expand_path("../../worklog.rb", __FILE__)
EOF
chmod +x ~/environment/worklog/bin/worklog
```

### 3. PATHを通す

`.zshrc`（または `.bashrc`）に追記:

```bash
export PATH="$HOME/environment/worklog/bin:$PATH"
```

反映:

```bash
source ~/.zshrc
```

### 4. 動作確認

```bash
worklog help
```

## 使い方

### 作業の記録（日中こまめに）

```bash
# タスクを追加（時間ブロックは自動判定）
worklog add "meiji: XXXXXX"

# 直前のタスクにメモを追加
worklog note "Logの量確認"
worklog note "XXXXXX"

# さらに深いインデントのメモ
worklog note -d 2 "昨日の対応と合わせてかなり減ったはず"
```

### 終業時

```bash
# 振り返りを追加
worklog retro "meiji: XXXXXX"

# 明日のやることを追加
worklog todo "meiji: XXXXXX"

# プレビュー確認
worklog review

# 内容をクリップボードにコピー（Discordに貼り付けて投稿）
worklog post
```

### その他

```bash
# エディタで直接編集（細かい修正に）
worklog edit

# リマインド設定のヘルプ
worklog remind
```

## 出力例

```
### 2026/03/10(火)

10:00 〜
* meiji: 障害対応時の情報の更新
* すかいらーく: MTG
* 定例(火)
* meiji: 開発: XXXXXX
12:00 〜
* meiji: 設定調整
   * Logの量確認
   * 開発/STG: 拡張モニタリングOFF

本日の業務振り返り

* meiji: XXXXXXに関して要確認

明日のやること

* meiji: XXXXXXチェック機能
```

## 環境変数

| 変数名 | デフォルト | 説明 |
|---|---|---|
| `WORKLOG_DIR` | `~/environment/worklog` | ログファイルの保存先 |
| `WORKLOG_BLOCK_INTERVAL` | `2` | 時間ブロックの間隔（時間） |
| `WORKLOG_START_HOUR` | `10` | 業務開始時刻（時） |
| `EDITOR` | `vim` | `worklog edit` で使うエディタ |

## リマインド設定（任意）

`crontab -e` で以下を追加すると、2時間ごとに記録を促す通知が届く:

```cron
# macOS
0 10,12,14,16,18 * * 1-5 osascript -e 'display notification "作業ログを記録しましょう！" with title "worklog"'

# 終業時にクリップボードコピー（19:00）
0 19 * * 1-5 $HOME/environment/worklog/bin/worklog post
```

## 依存

- Ruby（標準ライブラリのみ、gem不要）
