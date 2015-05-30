require "yaml"
require_relative "error"

module Parallel
  class ForkManager
    # TODO: Maybe make this into a factory, given the number of case statements
    # switching on type.  This is a "shameless green" if you use Sandi Metz's
    # terminology.
    class Serializer
      ##
      # Raises a {Parallel::ForkManager::UnknownSerializerError} exception if
      # +type+ isn't one of +marshal+ or +yaml+
      #
      # @param type [String] The type of serialization to use.
      def initialize(type)
        @type = validate_type(type)
      end

      ##
      # @param data_structure [Object] the data to be serialized.
      # @return [String] the serialized representation of the data.
      def serialize(data_structure)
        case type
        when :marshal
          Marshal.dump(data_structure)
        when :yaml
          YAML.dump(data_structure)
        end
      end

      ##
      # @param serialized [String] the serialized representation of the data.
      # @return [Object] the resonstituted data structure.
      def deserialize(serialized)
        case type
        when :marshal
          Marshal.load(serialized)
        when :yaml
          YAML.load(serialized)
        end
      end

      private

      attr_reader :type

      def validate_type(t)
        case t.downcase
        when "marshal"
          :marshal
        when "yaml"
          :yaml
        else
          fail Parallel::ForkManager::UnknownSerializerError
        end
      end
    end
  end
end
