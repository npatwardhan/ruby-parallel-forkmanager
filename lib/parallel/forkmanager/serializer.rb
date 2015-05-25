require "yaml"
require_relative "error"

module Parallel
  class ForkManager
    # TODO: Maybe make this into a factory, given the number of case statements
    # switching on type.  This is a "shameless green" if you use Sandi Metz's
    # terminology.
    class Serializer
      def initialize(type = nil)
        @type = validate_type(type)
      end

      def serialize(data_structure)
        case type
        when :marshal
          Marshal.dump(data_structure)
        when :yaml
          YAML.dump(data_structure)
        end
      end

      def deserialize(data)
        case type
        when :marshal
          Marshal.load(data)
        when :yaml
          YAML.load(data)
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
