#!/usr/bin/env ruby
# frozen_string_literal: true

# ============================================================
# worklog - Daily Work Log CLI
# ============================================================

require "json"
require "net/http"
require "uri"
require "fileutils"
require "date"

module Worklog
  WEEKDAYS_JA = %w[日 月 火 水 木 金 土].freeze

  class Config
    attr_reader :log_dir, :webhook_url, :block_interval, :start_hour, :editor

    def initialize
      @log_dir        = ENV.fetch("WORKLOG_DIR", File.join(Dir.home, "worklogs"))
      @webhook_url    = ENV["DISCORD_WEBHOOK_URL"]
      @block_interval = ENV.fetch("WORKLOG_BLOCK_INTERVAL", "2").to_i
      @start_hour     = ENV.fetch("WORKLOG_START_HOUR", "10").to_i
      @editor         = ENV.fetch("EDITOR", "vim")
    end
  end

  class LogFile
    def initialize(config, date: Date.today)
      @config = config
      @date   = date
      @path   = File.join(config.log_dir, "#{date.strftime('%Y-%m-%d')}.md")
    end

    attr_reader :path

    def exists? = File.exist?(@path)

    def read = File.read(@path)

    def write(content)
      File.write(@path, content)
    end

    def lines = exists? ? File.readlines(@path, chomp: true) : []

    # --- ヘッダー ---

    def header
      dow = WEEKDAYS_JA[@date.wday]
      "#{@date.strftime('%Y/%m/%d')}(#{dow})"
    end

    # --- 現在の時間ブロック ---

    def current_time_block
      hour = Time.now.hour
      block_hour = (((hour - @config.start_hour) / @config.block_interval) * @config.block_interval) + @config.start_hour
      block_hour = @config.start_hour if block_hour < @config.start_hour
      format("%02d:00 〜", block_hour)
    end

    # --- ファイル初期化 ---

    def init!
      FileUtils.mkdir_p(File.dirname(@path))
      return if exists?

      write("#{header}\nタイムライン\n")
      warn "📄 新しいログファイルを作成しました: #{@path}"
    end

    # --- セクション位置の検出 ---

    def find_section_line(section_name)
      lines.index(section_name)
    end

    # --- 時間ブロックの確保 ---

    def ensure_time_block(block)
      return if lines.any? { |l| l == block }

      current = lines.dup
      retro_idx = current.index("本日の業務振り返り")

      if retro_idx
        current.insert(retro_idx, block, "")
      else
        current << "" << block
      end

      write(current.join("\n") + "\n")
    end

    # --- セクションの確保 ---

    def ensure_section(section_name)
      return if lines.any? { |l| l == section_name }

      current = lines.dup
      current << "" << section_name
      write(current.join("\n") + "\n")
    end

    # --- タイムラインのブロック末尾にタスクを追加 ---

    def append_to_block(block, content)
      ensure_time_block(block)
      current = lines.dup

      # 対象ブロック内の最後の行を探す
      block_idx = current.index(block)
      return unless block_idx

      last_content_idx = block_idx
      (block_idx + 1...current.size).each do |i|
        line = current[i]
        break if line.match?(/^\d{2}:00 〜/) || line == "本日の業務振り返り" || line == "明日のやること"

        last_content_idx = i unless line.empty?
      end

      current.insert(last_content_idx + 1, content)
      write(current.join("\n") + "\n")
    end

    # --- タイムライン内の最後のbullet行の後にメモを追加 ---

    def append_note(content)
      current = lines.dup

      # タイムラインセクション内で最後の bullet 行を見つける
      last_bullet_idx = nil
      current.each_with_index do |line, i|
        break if line == "本日の業務振り返り" || line == "明日のやること"

        last_bullet_idx = i if line.match?(/^\s*\* /)
      end

      unless last_bullet_idx
        warn "❌ 追記先のタスクが見つかりません。先に worklog add でタスクを追加してください。"
        exit 1
      end

      current.insert(last_bullet_idx + 1, content)
      write(current.join("\n") + "\n")
    end

    # --- セクションの末尾にエントリ追加 ---

    def append_to_section(section_name, content)
      ensure_section(section_name)
      current = lines.dup

      section_idx = current.index(section_name)
      return unless section_idx

      # セクション以降で次のセクション or EOF を探す
      insert_idx = current.size
      (section_idx + 1...current.size).each do |i|
        if current[i] == "本日の業務振り返り" || current[i] == "明日のやること"
          # 同じセクション名の場合はスキップ
          next if current[i] == section_name

          insert_idx = i
          break
        end
      end

      current.insert(insert_idx, content)
      write(current.join("\n") + "\n")
    end

    # --- タスク数カウント ---

    def task_count
      lines.count { |l| l.match?(/^\* /) }
    end

    # --- 文字数 ---

    def char_count
      exists? ? read.length : 0
    end
  end

  # ============================================================
  # コマンド群
  # ============================================================

  class CLI
    def initialize
      @config = Config.new
    end

    def run(args)
      cmd = args.shift || "help"

      case cmd
      when "add"     then cmd_add(args)
      when "note"    then cmd_note(args)
      when "retro"   then cmd_retro(args)
      when "todo"    then cmd_todo(args)
      when "review"  then cmd_review
      when "edit"    then cmd_edit
      when "post"    then cmd_post(args)
      when "remind"  then cmd_remind
      when "help", "-h", "--help" then cmd_help
      else
        warn "❌ 不明なコマンド: #{cmd}"
        warn "   worklog help でヘルプを表示"
        exit 1
      end
    end

    private

    def log_file
      @log_file ||= LogFile.new(@config)
    end

    # --- add ---

    def cmd_add(args)
      abort "Usage: worklog add \"タスク内容\"" if args.empty?

      content = args.join(" ")
      log_file.init!

      block = log_file.current_time_block
      log_file.append_to_block(block, "* #{content}")

      timestamp = Time.now.strftime("%H:%M")
      warn "✅ [#{timestamp}] #{block} に追加: #{content}"
    end

    # --- note ---

    def cmd_note(args)
      depth = 1

      if args.first == "-d"
        args.shift
        depth = (args.shift || 1).to_i
      end

      abort "Usage: worklog note [-d depth] \"メモ内容\"" if args.empty?

      unless log_file.exists?
        warn "❌ 今日のログファイルがありません。先に worklog add でタスクを追加してください。"
        exit 1
      end

      content = args.join(" ")
      indent = "   " * depth

      log_file.append_note("#{indent}* #{content}")
      warn "📝 メモ追加: #{content}"
    end

    # --- retro ---

    def cmd_retro(args)
      abort "Usage: worklog retro \"振り返り内容\"" if args.empty?

      content = args.join(" ")
      log_file.init!
      log_file.append_to_section("本日の業務振り返り", "* #{content}")
      warn "🔍 振り返り追加: #{content}"
    end

    # --- todo ---

    def cmd_todo(args)
      abort "Usage: worklog todo \"明日やること\"" if args.empty?

      content = args.join(" ")
      log_file.init!
      log_file.append_to_section("明日のやること", "* #{content}")
      warn "📋 明日のやること追加: #{content}"
    end

    # --- review ---

    def cmd_review
      unless log_file.exists?
        warn "📭 今日のログはまだありません。"
        return
      end

      warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      puts log_file.read
      warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      warn "📊 タスク数: #{log_file.task_count}"
    end

    # --- edit ---

    def cmd_edit
      log_file.init!
      system(@config.editor, log_file.path)
    end

    # --- post ---

    def cmd_post(args)
      dry_run = args.include?("--dry-run")

      unless log_file.exists?
        warn "❌ 今日のログがありません。"
        exit 1
      end

      content = log_file.read
      chars = content.length

      if dry_run
        warn "🔍 投稿プレビュー (#{chars} 文字):"
        warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        puts content
        warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        warn "ℹ️  --dry-run モードです。実際の送信はされていません。"
        return
      end

      if @config.webhook_url.nil? || @config.webhook_url.empty?
        warn "❌ DISCORD_WEBHOOK_URL が設定されていません。"
        warn '   export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."'
        exit 1
      end

      if chars <= 2000
        send_to_discord(content)
      else
        warn "⚠️  内容が #{chars} 文字あります（Discord上限: 2000文字）"
        warn "   分割して送信します。"
        split_and_send(content)
      end

      warn "✅ Discordに投稿しました！"
    end

    # --- Discord送信 ---

    def send_to_discord(message)
      uri = URI.parse(@config.webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate({ content: message })

      response = http.request(request)

      unless %w[200 204].include?(response.code)
        warn "❌ Discord送信エラー (HTTP #{response.code})"
        exit 1
      end
    end

    def split_and_send(content)
      chunks = []
      current_chunk = ""

      content.each_line do |line|
        if current_chunk.length + line.length > 1900
          chunks << current_chunk
          current_chunk = ""
        end
        current_chunk += line
      end
      chunks << current_chunk unless current_chunk.empty?

      chunks.each_with_index do |chunk, i|
        warn "📤 Part #{i + 1} を送信中..."
        send_to_discord(chunk)
        sleep 1 if i < chunks.size - 1 # レート制限対策
      end
    end

    # --- remind ---

    def cmd_remind
      warn "⏰ リマインド設定方法:"
      warn ""
      warn "crontab に以下を追加すると、2時間ごとに通知されます:"
      warn ""

      if RUBY_PLATFORM.include?("darwin")
        warn '  # macOS: 通知センター経由'
        warn "  0 10,12,14,16,18 * * 1-5 osascript -e 'display notification \"作業ログを記録しましょう！\" with title \"worklog\"'"
      else
        warn '  # Linux: notify-send 経由'
        warn '  0 10,12,14,16,18 * * 1-5 DISPLAY=:0 notify-send "worklog" "作業ログを記録しましょう！"'
      end

      warn ""
      warn "  # 終業時に自動投稿したい場合（例: 19:00）:"
      warn "  0 19 * * 1-5 /usr/local/bin/worklog post"
      warn ""
      warn "crontab -e で編集できます。"
    end

    # --- help ---

    def cmd_help
      warn <<~HELP
        worklog - Daily Work Log CLI

        コマンド:
          worklog add "内容"              作業項目を追加（時間ブロック自動判定）
          worklog note "メモ"             直前の項目にサブメモを追加
          worklog note -d 2 "メモ"        インデント深さ指定でサブメモ追加
          worklog retro "振り返り"        本日の業務振り返りに追加
          worklog todo "やること"         明日のやることに追加
          worklog review                  今日のログをプレビュー
          worklog edit                    エディタで直接編集
          worklog post                    Discordに投稿
          worklog post --dry-run          投稿プレビュー（送信しない）
          worklog remind                  リマインド設定のヘルプ
          worklog help                    このヘルプを表示

        環境変数:
          DISCORD_WEBHOOK_URL          Discord Webhook URL（必須: post時）
          WORKLOG_DIR                     ログ保存先 (デフォルト: ~/worklogs)
          WORKLOG_BLOCK_INTERVAL          時間ブロックの間隔 (デフォルト: 2時間)
          WORKLOG_START_HOUR              業務開始時刻 (デフォルト: 10)
          EDITOR                       エディタ (デフォルト: vim)

        使用例:
          worklog add "MRNX: 開発: SolidQueueの停止処理"
          worklog note "Logの量確認"
          worklog note -d 2 "開発/STG: 拡張モニタリングOFF"
          worklog retro "MRNX: QuickSightに関して要確認"
          worklog todo "MRNX: QuickSuite調整 / IMEIチェック機能"
          worklog review
          worklog post
      HELP
    end
  end
end

Worklog::CLI.new.run(ARGV.dup)
