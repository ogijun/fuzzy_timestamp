# frozen_string_literal: true

require_relative "lib/fuzzy_timestamp/version"

Gem::Specification.new do |spec|
  spec.name = "fuzzy_timestamp"
  spec.version = FuzzyTimestamp::VERSION
  spec.authors = [ "Junya Ogino" ]
  spec.email = [ "ogijun@gmail.com" ]

  spec.summary = "Timestamps with variable precision (year / month / day / minute or unknown) as one ISO 8601 string."
  spec.description = <<~DESC
    Stores a point in time whose precision varies — "2026", "2026-03", "2026-03-05", "2026-03-05T14:30",
    or nil for unknown — as a single reduced-precision ISO 8601 string. Sorting the strings sorts the
    timestamps, with a coarser value at the start of its period. Parses and labels Japanese input
    ("2026年3月5日 14時", "昨日", "去年").
  DESC
  spec.homepage = "https://github.com/ogijun/fuzzy_timestamp"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = [ "lib" ]
end
