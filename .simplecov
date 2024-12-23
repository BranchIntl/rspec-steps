require 'simplecov-json'

SimpleCov.start do
  coverage_dir "coverage"
  add_filter "./spec"
  add_filter "vendor/bundle"
  formatter SimpleCov::Formatter::MultiFormatter[
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter,
  ]
end
