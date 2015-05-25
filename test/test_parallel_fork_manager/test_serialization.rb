# We don't need documentation for the classes for minitest classes
#
# rubocop:disable Style/Documentation
require "minitest_helper"

module TestParallelForkManager
  class TestSerialization < Minitest::Test
    FINISH_DATA = { foo: "bar".freeze, baz: nil }.freeze

    def test_marshal
      run_test(params: { "serialize_as" => "marshal" })
    end

    def test_yaml
      run_test(params: { "serialize_as" => "yaml" })
    end

    def test_unknown_serializer
      assert_raises(Parallel::ForkManager::UnknownSerializerError) do
        run_test(params: { "serialize_as" => "" })
      end
    end

    def test_serialize_type_key
      run_test(params: { "serialize_type" => "marshal" })
    end

    def test_with_default_serializer
      # It seems that the default serializer is only set up if there are other
      # params passed into the constructor.
      run_test(params: { "foo" => "bar" })

      # If we run with no parmeters then the serializer isn't set up, so we get
      # an empty hash back.
      run_test(expected: {})
    end

    def run_test(params: {}, expected: FINISH_DATA)
      pfm = Parallel::ForkManager.new(1, params)
      returned_ds = nil
      pfm.run_on_finish do |pid, exit_code, ident, exit_signal, core_dump, ds|
        returned_ds = ds
      end

      unless pfm.start
        # ... in the child ...
        pfm.finish(0, FINISH_DATA)
      end
      pfm.wait_all_children

      assert_equal expected, returned_ds
    end
  end
end
