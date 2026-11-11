require "test_helper"

# #75 NFR-14: ทุกข้อ BID-* ใน requirements/04-bidding.md ต้องมีเทสต์อ้างถึง (ชื่อเทสต์ขึ้นต้นด้วยรหัสข้อ)
# NFR-15: CI ต้องรัน rubocop, brakeman และเทสต์ทุกครั้ง
class RequirementsCoverageTest < ActiveSupport::TestCase
  ROOT = Rails.root

  def all_test_sources
    Dir[ROOT.join("test/**/*_test.rb")].reject { |f| f.end_with?("requirements_coverage_test.rb") }.map { |f| File.read(f) }.join("\n")
  end

  test "NFR-14: ทุกข้อ BID-* มีเทสต์อ้างถึง" do
    ids = File.read(ROOT.join("requirements/04-bidding.md")).scan(/^\|\s*(BID-\d+[a-z]?)\s/).flatten.uniq
    assert_operator ids.size, :>=, 20, "อ่านรหัสข้อจาก requirements ไม่ได้"
    sources = all_test_sources
    missing = ids.reject { |id| sources.match?(/#{Regexp.escape(id)}(?![0-9a-z])/) }
    assert_empty missing, "BID-* ที่ยังไม่มีเทสต์อ้างถึง: #{missing.join(', ')}"
  end

  test "NFR-15: CI รัน brakeman, rubocop และเทสต์" do
    ci = File.read(ROOT.join(".github/workflows/ci.yml"))
    %w[bin/brakeman bin/rubocop].each { |cmd| assert_includes ci, cmd }
    assert_match(/bin\/rails .*test/, ci)
  end
end
