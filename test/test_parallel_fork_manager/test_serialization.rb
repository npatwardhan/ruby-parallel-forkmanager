# We don't need documentation for the classes for minitest classes
#
# rubocop:disable Style/Documentation
require "minitest_helper"

module TestParallelForkManager
  class TestSerialization < Minitest::Test
    DEFAULT_RETURN = { foo: "bar".freeze, baz: nil }.freeze

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
      run_test
    end

    def test_non_hash_data_return
      data = "This is a string"
      run_test(params: { "serialize_as" => "yaml" },
               return: data,
               expected: data)
    end

    def run_test(args = {})
      params = args.fetch(:params, {})
      return_data = args.fetch(:return, DEFAULT_RETURN)
      expected = args.fetch(:expected, DEFAULT_RETURN)

      pfm = Parallel::ForkManager.new(1, params)
      returned_data = nil
      pfm.run_on_finish do |_pid, _exit_code, _ident, _exit_signal, _core_dump, data|
        returned_data = data
      end

      unless pfm.start
        # ... in the child ...
        pfm.finish(0, return_data)
      end
      pfm.wait_all_children

      assert_equal expected, returned_data
    end
  end
end
