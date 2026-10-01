# frozen_string_literal: true

require "date"
require_relative "fuzzy_timestamp/version"

# 精度が可変の日時。ISO 8601 の精度を落とした文字列1つで表す:
#
#   "2026"              年
#   "2026-03"           月
#   "2026-03-05"        日
#   "2026-03-05T14:30"  分 (時刻は分まで)
#   nil                 不明
#
# 精度は桁数そのものなので、日時と精度を別に持って食い違う、という状態がない。
# 文字列のまま並べると日時の順になり、粗い値はその期間の初めに来る ("2026" < "2026-03" < "2026-03-05")。
# タイムゾーンは持たない (その場所の時計の時刻)。
#
# 状態を持たない関数だけ。「今」は now: で受け取る (呼び出し側のタイムゾーンで決めるため)。
module FuzzyTimestamp
  FORMAT = /\A(\d{4})(?:-(\d{2})(?:-(\d{2})(?:T(\d{2}):(\d{2}))?)?)?\z/
  SEPARATOR = %r{[/.\-]}
  # 末尾の時刻。「14:30」「14時」「14時30分」。日付とは空白か「T」で区切るか、「日」に続けて書く。
  TIME = /(?:\A|[\sT]|(?<=日))(\d{1,2})(?::(\d{2})|時(?:(\d{1,2})分)?)\z/
  WORDS = {
    "今日" => ->(today) { from_date(today) },
    "昨日" => ->(today) { from_date(today - 1) },
    "一昨日" => ->(today) { from_date(today - 2) },
    "おととい" => ->(today) { from_date(today - 2) },
    "今月" => ->(today) { today.strftime("%Y-%m") },
    "先月" => ->(today) { today.prev_month.strftime("%Y-%m") },
    "今年" => ->(today) { today.year.to_s },
    "去年" => ->(today) { today.prev_year.year.to_s },
    "昨年" => ->(today) { today.prev_year.year.to_s }
  }.freeze
  # label(nil) の「日付不明」と対になる書き方。空欄と同じく不明 (nil) として読む。
  UNKNOWN = %w[不明 日付不明].freeze

  module_function

  # 書かれた日時を読み取る。「2026/9/25」「2026年9月」「2026」「9/25」(今年)「20260925」「今日」「先月」
  # 「去年」、それに時刻を付けた「2026/9/25 14:30」「昨日 9:05」「14時」(今日) など。全角も読む。
  # 空か「不明」なら nil (不明)。読めないものは書いたまま返す (正しさは valid? で判定する)。
  def parse(text, now:)
    text = text.to_s.unicode_normalize(:nfkc).strip
    return if text.empty? || UNKNOWN.include?(text)

    today = now.to_date
    time = TIME.match(text)
    date = time ? parse_date(text[0, time.begin(0)].strip, today) : parse_date(text, today)
    return date || text unless time

    date = from_date(today) if text[0, time.begin(0)].strip.empty?
    return text unless date && precision(date) == :day

    "#{date}T#{pad(time[1])}:#{pad(time[2] || time[3] || '0')}"
  end

  def parse_date(text, today)
    return WORDS[text].call(today) if WORDS.key?(text)

    case text
    when /\A(\d{4})(\d{2})(\d{2})\z/ then join(Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3))
    when /\A(\d{4})年?\z/ then Regexp.last_match(1)
    when /\A(\d{4})(?:#{SEPARATOR}|年)(\d{1,2})月?\z/ then join(Regexp.last_match(1), Regexp.last_match(2))
    when /\A(\d{4})(?:#{SEPARATOR}|年)(\d{1,2})(?:#{SEPARATOR}|月)(\d{1,2})日?\z/
      join(Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3))
    when /\A(\d{1,2})(?:#{SEPARATOR}|月)(\d{1,2})日?\z/
      join(today.year.to_s, Regexp.last_match(1), Regexp.last_match(2))
    end
  end

  def from_date(date) = date.strftime("%Y-%m-%d")

  def from_time(time) = time.strftime("%Y-%m-%dT%H:%M")

  def valid?(value)
    return true if value.nil?

    match = FORMAT.match(value.to_s) or return false
    year, month, day, hour, minute = match.captures.map { |part| part&.to_i }
    return true unless month
    return (1..12).cover?(month) unless day
    return false unless Date.valid_date?(year, month, day)

    hour.nil? || ((0..23).cover?(hour) && (0..59).cover?(minute))
  end

  # :year / :month / :day / :minute。不明や読めない値は nil。
  def precision(value)
    match = FORMAT.match(value.to_s) or return
    return :minute if match[4]
    return :day if match[3]
    return :month if match[2]

    :year
  end

  def label(value)
    parts = parts(value)
    return "日付不明" unless parts[:year]

    date = [ "#{parts[:year]}年", parts[:month] && "#{parts[:month]}月", parts[:day] && "#{parts[:day]}日" ].compact.join
    parts[:hour] ? "#{date} #{parts[:hour]}:#{format('%02d', parts[:minute].to_i)}" : date
  end

  # 入力欄に戻すときの書き方 ("2026/9/5 14:30")。読めない値は書いたまま。
  def input_value(value)
    parts = parts(value)
    return value.to_s unless parts[:year]

    date = parts.values_at(:year, :month, :day).compact.join("/")
    parts[:hour] ? "#{date} #{parts[:hour]}:#{format('%02d', parts[:minute].to_i)}" : date
  end

  # 年・月・日・時・分 (先頭の 0 は落とす)。無い部分は nil。
  def parts(value)
    captures = FORMAT.match(value.to_s)&.captures || []
    year, *rest = captures
    %i[year month day hour minute].zip([ year, *rest.map { |part| part&.to_i&.to_s } ]).to_h
  end

  def join(year, *rest) = [ year, *rest.map { |part| pad(part) } ].join("-")

  def pad(part) = part.to_s.rjust(2, "0")
end
