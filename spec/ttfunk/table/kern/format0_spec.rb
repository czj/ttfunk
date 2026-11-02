# frozen_string_literal: true

require 'spec_helper'
require 'ttfunk/table/kern'

RSpec.describe TTFunk::Table::Kern::Format0 do
  subject(:subtable) { described_class.new(version: 0, coverage: 1, data: data) }

  # num_pairs, search_range, entry_selector, range_shift, then
  # (left, right, value) records
  let(:data) { [3, 12, 1, 6, 1, 2, -40, 1, 3, 25, 4, 2, -3].pack('n*') }

  describe '#pairs' do
    it 'maps each glyph pair to its signed value' do
      expect(subtable.pairs).to eq([1, 2] => -40, [1, 3] => 25, [4, 2] => -3)
    end

    context 'when the subtable claims more pairs than it holds' do
      let(:data) { [3, 12, 1, 6, 1, 2, -40, 1, 3, 25, 4, 2].pack('n*') }

      it 'reads only the complete records' do
        expect(subtable.pairs).to eq([1, 2] => -40, [1, 3] => 25)
      end
    end

    context 'when the subtable holds the 65535 pairs its count allows' do
      let(:data) do
        records = (0...65_535).flat_map { |index| [index >> 8, index & 0xFF, -index % 7] }
        [65_535, 0, 0, 0, *records].pack('n*')
      end

      it 'reads them all' do
        expect(subtable.pairs.size).to eq(65_535)
      end
    end

    it 'matches every record of a real font' do
      font = TTFunk::File.open(test_font('DejaVuSans'))
      num_pairs = font.kerning.raw.unpack1('n', offset: 10)
      records = font.kerning.raw.unpack("@18#{'nns>' * num_pairs}").each_slice(3)
      expected = records.to_h { |left, right, value| [[left, right], value] }

      expect(font.kerning.tables.first.pairs).to eq(expected)
    end
  end

  describe '#kerning_value' do
    it 'returns the value of a kerned pair' do
      expect(subtable.kerning_value(1, 3)).to eq(25)
    end

    it 'returns nil for a pair without kerning' do
      expect(subtable.kerning_value(2, 1)).to be_nil
    end
  end

  describe '#recode' do
    it 'keeps the pairs whose glyphs are both in the subset, with their new IDs' do
      recoded = described_class.new(data: subtable.recode(1 => 10, 2 => 20, 4 => 40)[6..])

      expect(recoded.pairs).to eq([10, 20] => -40, [40, 20] => -3)
    end

    it 'returns nil when no pair survives the subset' do
      expect(subtable.recode(1 => 10)).to be_nil
    end
  end
end
