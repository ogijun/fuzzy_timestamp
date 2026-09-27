# fuzzy_timestamp

Timestamps whose precision varies — a year, a month, a day, or a minute, or unknown — stored as
**one reduced-precision ISO 8601 string**.

| value | precision | label |
|---|---|---|
| `"2026"` | year | 2026年 |
| `"2026-03"` | month | 2026年3月 |
| `"2026-03-05"` | day | 2026年3月5日 |
| `"2026-03-05T14:30"` | minute | 2026年3月5日 14:30 |
| `nil` | unknown | 日付不明 |

- **The precision is the length of the string**, so a value and its precision can never disagree
  (there is no separate precision column to keep in sync).
- **Sorting the strings sorts the timestamps.** A coarser value sits at the start of its period:
  `"2026" < "2026-03" < "2026-03-05" < "2026-03-05T09:05"`. In SQL, `ORDER BY ... DESC` puts `NULL`
  (unknown) last in SQLite.
- **No time zone.** Times are wall-clock times of wherever it happened.
- Pure Ruby, stateless functions, no dependencies. Labels and parsing are Japanese.

## Usage

```ruby
require "fuzzy_timestamp"

FuzzyTimestamp.parse("2026/3/5 14:30", now: Time.now)  # => "2026-03-05T14:30"
FuzzyTimestamp.parse("2026年3月", now: Time.now)       # => "2026-03"
FuzzyTimestamp.parse("昨日 9:05", now: Time.now)        # => e.g. "2026-09-24T09:05"
FuzzyTimestamp.parse("", now: Time.now)                 # => nil (unknown)
FuzzyTimestamp.parse("あした", now: Time.now)           # => "あした" (unreadable; valid? rejects it)

FuzzyTimestamp.valid?("2026-02-30")                     # => false
FuzzyTimestamp.precision("2026-03")                     # => :month
FuzzyTimestamp.label("2026-03-05T14:30")                # => "2026年3月5日 14:30"
FuzzyTimestamp.input_value("2026-03-05T14:30")          # => "2026/3/5 14:30"
FuzzyTimestamp.from_time(Time.now)                      # => e.g. "2026-09-25T10:00"
```

`parse` reads `2026/9/25`, `2026-9-25`, `2026.9.25`, `2026年9月25日`, `20260925`, `2026/9`, `2026年9月`,
`2026`, `9/25` (this year), full-width characters, the words `今日` `昨日` `一昨日` `今月` `先月` `今年` `去年`,
and a time after a day: `14:30`, `14時`, `14時30分` (`14:30` alone means today).
Pass `now:` in your application's time zone (e.g. `Time.current` in Rails).

## License

MIT
