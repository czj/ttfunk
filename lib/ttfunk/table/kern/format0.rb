# frozen_string_literal: true

module TTFunk
  class Table
    class Kern
      # Format 0 kerning subtable.
      class Format0
        # Subtable attributes.
        # @return [Hash{Symbol => any}]
        attr_reader :attributes

        # @param attributes [Hash{Symbol => any}]
        def initialize(attributes = {})
          @attributes = attributes
          @data = attributes.delete(:data)
        end

        # Kerning pairs.
        #
        # Allocates one array per pair: prefer {#kerning_value} for lookups.
        #
        # @return [Hash{Array(Integer, Integer) => Integer}]
        def pairs
          @pairs ||= value_by_pair_key.transform_keys { |key| [key >> 16, key & 0xFFFF] }
        end

        # Kerning value of a glyph pair.
        #
        # @param left [Integer] left glyph ID
        # @param right [Integer] right glyph ID
        # @return [Integer, nil] `nil` when the pair is not kerned
        def kerning_value(left, right)
          value_by_pair_key[(left << 16) | right]
        end

        # Is this vertical kerning?
        # @return [Boolean]
        def vertical?
          @attributes[:vertical]
        end

        # Is this horizontal kerning?
        # @return [Boolean]
        def horizontal?
          !vertical?
        end

        # Is this cross-stream kerning?
        # @return [Boolean]
        def cross_stream?
          @attributes[:cross]
        end

        # Recode this subtable using the specified mapping.
        #
        # @param mapping [Hash{Integer => Integer}] keys are old glyph IDs,
        #   values are new glyph IDs
        # @return [String]
        def recode(mapping)
          subset = []
          value_by_pair_key.each do |key, value|
            left = mapping[key >> 16]
            right = mapping[key & 0xFFFF]
            subset.push(left, right, value) if left && right
          end

          return if subset.empty?

          num_pairs = subset.length / 3
          search_range = 2 * (2**Integer(Math.log(num_pairs) / Math.log(2)))
          entry_selector = Integer(Math.log(search_range / 2) / Math.log(2))
          range_shift = (2 * num_pairs) - search_range

          [
            attributes[:version],
            (num_pairs * 6) + 14,
            attributes[:coverage],
            num_pairs,
            search_range,
            entry_selector,
            range_shift,
            *subset,
          ].pack('n*')
        end

        private

        # A pair record is a big-endian uint32 key (`left << 16 | right`)
        # followed by an int16 value, so `Ns>` reads it ready to use.
        def value_by_pair_key
          @value_by_pair_key ||=
            begin
              # sanity check, in case there's a bad length somewhere
              num_pairs = [@data.unpack1('n'), (@data.bytesize - 8) / 6].min
              Hash[*@data.unpack("@8#{'Ns>' * num_pairs}")]
            end
        end
      end
    end
  end
end
