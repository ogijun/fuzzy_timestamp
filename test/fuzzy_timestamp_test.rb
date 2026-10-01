# frozen_string_literal: true

require "minitest/autorun"
require "fuzzy_timestamp"

class FuzzyTimestampTest < Minitest::Test
  NOW = Time.new(2026, 9, 25, 10, 0)

  def parse(text) = FuzzyTimestamp.parse(text, now: NOW)

  # parse

  def test_reads_dates_by_precision
    {
      "2026/9/25" => "2026-09-25", "2026-09-25" => "2026-09-25", "2026.9.25" => "2026-09-25",
      "2026年9月25日" => "2026-09-25", "20260925" => "2026-09-25", " 2026/9/25 " => "2026-09-25",
      "2026/9" => "2026-09", "2026-9" => "2026-09", "2026年9月" => "2026-09",
      "2026" => "2026", "2026年" => "2026"
    }.each { |text, expected| assert_equal expected, parse(text), text }
  end

  def test_reads_times_to_the_minute
    {
      "2026/9/25 14:30" => "2026-09-25T14:30", "2026-09-25T14:30" => "2026-09-25T14:30",
      "2026年9月25日 14時" => "2026-09-25T14:00", "2026年9月25日14時30分" => "2026-09-25T14:30",
      "2026/9/25 9:05" => "2026-09-25T09:05", "3/5 14:30" => "2026-03-05T14:30",
      "14:30" => "2026-09-25T14:30", "14時" => "2026-09-25T14:00",
      "今日 14時" => "2026-09-25T14:00", "昨日 9:05" => "2026-09-24T09:05"
    }.each { |text, expected| assert_equal expected, parse(text), text }
  end

  def test_a_time_needs_a_whole_day
    assert_equal "2026/9 14:30", parse("2026/9 14:30")
    refute FuzzyTimestamp.valid?(parse("2026/9 14:30"))
  end

  def test_year_can_be_omitted
    assert_equal "2026-03-05", parse("3/5")
    assert_equal "2026-03-05", parse("3月5日")
  end

  def test_reads_full_width_characters
    assert_equal "2026-09-25", parse("２０２６／９／２５")
    assert_equal "2026-09-25T14:30", parse("２０２６／９／２５　１４：３０")
  end

  def test_reads_common_words
    {
      "今日" => "2026-09-25", "昨日" => "2026-09-24", "一昨日" => "2026-09-23", "おととい" => "2026-09-23",
      "今月" => "2026-09", "先月" => "2026-08", "今年" => "2026", "去年" => "2025", "昨年" => "2025"
    }.each { |text, expected| assert_equal expected, parse(text), text }
    assert_equal "2025-12", FuzzyTimestamp.parse("先月", now: Time.new(2026, 1, 10))
  end

  def test_blank_is_unknown
    assert_nil parse("")
    assert_nil parse("  ")
    assert_nil parse(nil)
  end

  def test_the_word_for_unknown_is_unknown
    assert_nil parse("不明")
    assert_nil parse("日付不明")
    assert_equal FuzzyTimestamp.label(nil), "日付不明"
  end

  def test_unreadable_text_is_returned_as_is_for_validation_to_reject
    assert_equal "あした", parse("あした")
    refute FuzzyTimestamp.valid?(parse("あした"))
    refute FuzzyTimestamp.valid?(parse("2026/2/30"))
    refute FuzzyTimestamp.valid?(parse("2026/9/25 25:00"))
  end

  def test_now_can_be_a_date
    assert_equal "2026-09-24", FuzzyTimestamp.parse("昨日", now: Date.new(2026, 9, 25))
  end

  # valid?

  def test_valid_values
    [ nil, "2026", "2026-12", "2024-02-29", "2026-09-25T00:00", "2026-09-25T23:59" ].each do |value|
      assert FuzzyTimestamp.valid?(value), value.inspect
    end
    [ "", "26", "2026-13", "2026-00", "2026-02-30", "2025-02-29", "2026-3-5", "2026-09-25T24:00",
      "2026-09-25T14:60", "2026-09-25T14", "2026-09T14:30", "2026-09-25 14:30" ].each do |value|
      refute FuzzyTimestamp.valid?(value), value.inspect
    end
  end

  # precision / label / input_value / parts

  def test_precision
    assert_equal :year, FuzzyTimestamp.precision("2026")
    assert_equal :month, FuzzyTimestamp.precision("2026-03")
    assert_equal :day, FuzzyTimestamp.precision("2026-03-05")
    assert_equal :minute, FuzzyTimestamp.precision("2026-03-05T14:30")
    assert_nil FuzzyTimestamp.precision(nil)
    assert_nil FuzzyTimestamp.precision("あした")
  end

  def test_label
    assert_equal "2026年3月5日 14:30", FuzzyTimestamp.label("2026-03-05T14:30")
    assert_equal "2026年3月5日 9:05", FuzzyTimestamp.label("2026-03-05T09:05")
    assert_equal "2026年3月5日", FuzzyTimestamp.label("2026-03-05")
    assert_equal "2026年3月", FuzzyTimestamp.label("2026-03")
    assert_equal "2026年", FuzzyTimestamp.label("2026")
    assert_equal "日付不明", FuzzyTimestamp.label(nil)
  end

  def test_input_value
    assert_equal "2026/9/5 14:30", FuzzyTimestamp.input_value("2026-09-05T14:30")
    assert_equal "2026/9/5", FuzzyTimestamp.input_value("2026-09-05")
    assert_equal "2026/9", FuzzyTimestamp.input_value("2026-09")
    assert_equal "2026", FuzzyTimestamp.input_value("2026")
    assert_equal "", FuzzyTimestamp.input_value(nil)
    assert_equal "あした", FuzzyTimestamp.input_value("あした")
  end

  def test_parts
    assert_equal({ year: "2026", month: "3", day: "5", hour: "14", minute: "30" }, FuzzyTimestamp.parts("2026-03-05T14:30"))
    assert_equal({ year: "2026", month: nil, day: nil, hour: nil, minute: nil }, FuzzyTimestamp.parts("2026"))
    assert_equal({ year: nil, month: nil, day: nil, hour: nil, minute: nil }, FuzzyTimestamp.parts(nil))
  end

  # from_date / from_time

  def test_from_date_and_time
    assert_equal "2026-03-05", FuzzyTimestamp.from_date(Date.new(2026, 3, 5))
    assert_equal "2026-03-05T14:30", FuzzyTimestamp.from_time(Time.new(2026, 3, 5, 14, 30, 59))
  end

  # ordering

  def test_sorting_the_strings_sorts_the_timestamps
    values = [ "2026-03-05T14:30", "2026", "2026-03-05", "2025-12", "2026-03-05T09:05", "2026-03" ]
    assert_equal [ "2025-12", "2026", "2026-03", "2026-03-05", "2026-03-05T09:05", "2026-03-05T14:30" ], values.sort
  end
end
