require "rails_helper"

RSpec.describe LessonService::SyncWordFamilies do
  let(:lesson) { create(:lesson) }

  it "creates word families in array order" do
    described_class.call(
      lesson,
      items: [
        { pattern: "..et", words: %w[net set] },
        { pattern: "..ed", words: %w[loaded needed] }
      ]
    )

    rows = lesson.reload.word_families
    expect(rows.map(&:pattern)).to eq([ "..et", "..ed" ])
    expect(rows.map(&:position)).to eq([ 0, 1 ])
    expect(rows.first.words).to eq(%w[net set])
  end

  it "destroys families omitted from the sync list" do
    keep = create(:word_family, lesson: lesson, pattern: "..et", words: %w[net], position: 0)
    drop = create(:word_family, lesson: lesson, pattern: "..ed", words: %w[loaded], position: 1)

    described_class.call(
      lesson,
      items: [ { id: keep.id, pattern: "..et", words: %w[net set] } ]
    )

    expect(lesson.reload.word_families.pluck(:id)).to eq([ keep.id ])
    expect(WordFamily.find_by(id: drop.id)).to be_nil
  end

  it "rejects blank patterns" do
    expect {
      described_class.call(lesson, items: [ { pattern: " ", words: %w[net] } ])
    }.to raise_error(LessonService::SyncWordFamilies::Error)
  end
end
