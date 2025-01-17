# frozen_string_literal: false

require_relative '../my_data'
require 'minitest/autorun'

class TestMyData < Minitest::Test
  # def test_additional_1
  #   klass = MyData.define(:foo, :bar)
  #   d = klass.new(foo: 1, bar: 2)
  #   assert_equal(1, d.foo)
  # end

  def test_define
    klass = MyData.define(:foo, :bar)
    assert_kind_of(Class, klass)
    assert_equal(%i[foo bar], klass.members)

    assert_raises(NoMethodError) { MyData.new(:foo) }
    assert_raises(TypeError) { MyData.define(0) }

    # Because some code is shared with Struct, check we don't share unnecessary functionality
    assert_raises(TypeError) { MyData.define(:foo, keyword_init: true) }

    refute(MyData.define.respond_to?(:define), "Cannot define from defined MyData class")
  end

  def test_define_edge_cases
    # non-ascii
    klass = MyData.define(:"r\u{e9}sum\u{e9}")
    o = klass.new(1)
    assert_equal(1, o.send(:"r\u{e9}sum\u{e9}"))

    # junk string
    klass = MyData.define(:"a\000")
    o = klass.new(1)
    assert_equal(1, o.send(:"a\000"))

    # special characters in attribute names
    klass = MyData.define(:a, :b?)
    x = Object.new
    o = klass.new("test", x)
    assert_same(x, o.b?)

    klass = MyData.define(:a, :b!)
    x = Object.new
    o = klass.new("test", x)
    assert_same(x, o.b!)

    assert_raises(ArgumentError) { MyData.define(:x=) }
    assert_raises(ArgumentError, /duplicate member/) { MyData.define(:x, :x) }
  end

  def test_define_with_block
    klass = MyData.define(:a, :b) do
      def c
        a + b
      end
    end

    assert_equal(3, klass.new(1, 2).c)
  end

  def test_initialize
    skip
    klass = MyData.define(:foo, :bar)

    # Regular
    test = klass.new(1, 2)
    assert_equal(1, test.foo)
    assert_equal(2, test.bar)
    assert_equal(test, klass.new(1, 2))
    assert_predicate(test, :frozen?)

    # Keywords
    test_kw = klass.new(foo: 1, bar: 2)
    assert_equal(1, test_kw.foo)
    assert_equal(2, test_kw.bar)
    assert_equal(test_kw, klass.new(foo: 1, bar: 2))
    assert_equal(test_kw, test)

    # Wrong protocol
    assert_raises(ArgumentError) { klass.new(1) }
    assert_raises(ArgumentError) { klass.new(1, 2, 3) }
    assert_raises(ArgumentError) { klass.new(foo: 1) }
    assert_raises(ArgumentError) { klass.new(foo: 1, bar: 2, baz: 3) }
    # Could be converted to foo: 1, bar: 2, but too smart is confusing
    assert_raises(ArgumentError) { klass.new(1, bar: 2) }
  end

  def test_initialize_redefine
    skip
    klass = MyData.define(:foo, :bar) do
      attr_reader :passed

      def initialize(*args, **kwargs)
        @passed = [args, kwargs]
        super(foo: 1, bar: 2) # so we can experiment with passing wrong numbers of args
      end
    end

    assert_equal([[], {foo: 1, bar: 2}], klass.new(foo: 1, bar: 2).passed)

    # Positional arguments are converted to keyword ones
    assert_equal([[], {foo: 1, bar: 2}], klass.new(1, 2).passed)

    # Missing arguments can be fixed in initialize
    assert_equal([[], {foo: 1}], klass.new(foo: 1).passed)
    assert_equal([[], {foo: 42}], klass.new(42).passed)

    # Extra keyword arguments can be dropped in initialize
    assert_equal([[], {foo: 1, bar: 2, baz: 3}], klass.new(foo: 1, bar: 2, baz: 3).passed)
  end

  def test_instance_behavior
    skip
    klass = MyData.define(:foo, :bar)

    test = klass.new(1, 2)
    assert_equal(1, test.foo)
    assert_equal(2, test.bar)
    assert_equal(%i[foo bar], test.members)
    assert_equal(1, test.public_send(:foo))
    assert_equal(0, test.method(:foo).arity)
    assert_equal([], test.method(:foo).parameters)

    assert_equal({foo: 1, bar: 2}, test.to_h)
    assert_equal({"foo"=>"1", "bar"=>"2"}, test.to_h { [_1.to_s, _2.to_s] })

    assert_equal({foo: 1, bar: 2}, test.deconstruct_keys(nil))
    assert_equal({foo: 1}, test.deconstruct_keys(%i[foo]))
    assert_equal({foo: 1}, test.deconstruct_keys(%i[foo baz]))
    assert_raises(TypeError) { test.deconstruct_keys(0) }

    assert_kind_of(Integer, test.hash)
  end

  def test_inspect
    skip
    klass = MyData.define(:a)
    o = klass.new(1)
    assert_equal("#<data a=1>", o.inspect)

    Object.const_set(:Foo, klass)
    assert_equal("#<data Foo a=1>", o.inspect)
    Object.instance_eval { remove_const(:Foo) }

    klass = MyData.define(:@a)
    o = klass.new(1)
    assert_equal("#<data :@a=1>", o.inspect)
  end

  def test_equal
    klass1 = MyData.define(:a)
    klass2 = MyData.define(:a)
    o1 = klass1.new(1)
    o2 = klass1.new(1)
    o3 = klass2.new(1)
    assert_equal(o1, o2)
    refute_equal(o1, o3)
  end

  def test_eql
    klass1 = MyData.define(:a)
    klass2 = MyData.define(:a)
    o1 = klass1.new(1)
    o2 = klass1.new(1)
    o3 = klass2.new(1)
    assert_operator(o1, :eql?, o2)
    refute_operator(o1, :eql?, o3)
  end

  def test_with
    klass = MyData.define(:foo, :bar)
    source = klass.new(foo: 1, bar: 2)

    # Simple
    test = source.with
    assert_equal(source.object_id, test.object_id)

    # Changes
    test = source.with(foo: 10)

    assert_equal(1, source.foo)
    assert_equal(2, source.bar)
    assert_equal(source, klass.new(foo: 1, bar: 2))

    assert_equal(10, test.foo)
    assert_equal(2, test.bar)
    assert_equal(test, klass.new(foo: 10, bar: 2))

    test = source.with(foo: 10, bar: 20)

    assert_equal(1, source.foo)
    assert_equal(2, source.bar)
    assert_equal(source, klass.new(foo: 1, bar: 2))

    assert_equal(10, test.foo)
    assert_equal(20, test.bar)
    assert_equal(test, klass.new(foo: 10, bar: 20))

    # Keyword splat
    changes = { foo: 10, bar: 20 }
    test = source.with(**changes)

    assert_equal(1, source.foo)
    assert_equal(2, source.bar)
    assert_equal(source, klass.new(foo: 1, bar: 2))

    assert_equal(10, test.foo)
    assert_equal(20, test.bar)
    assert_equal(test, klass.new(foo: 10, bar: 20))

    # Wrong protocol
    assert_raises(ArgumentError, "wrong number of arguments (given 1, expected 0)") do
      source.with(10)
    end
    assert_raises(ArgumentError, "unknown keywords: :baz, :quux") do
      source.with(foo: 1, bar: 2, baz: 3, quux: 4)
    end
    assert_raises(ArgumentError, "wrong number of arguments (given 1, expected 0)") do
      source.with(1, bar: 2)
    end
    assert_raises(ArgumentError, "wrong number of arguments (given 2, expected 0)") do
      source.with(1, 2)
    end
    assert_raises(ArgumentError, "wrong number of arguments (given 1, expected 0)") do
      source.with({ bar: 2 })
    end
  end

  def test_with_initialize
    skip
    oddclass = MyData.define(:odd) do
      def initialize(odd:)
        raise ArgumentError, "Not odd" unless odd.odd?
        super(odd: odd)
      end
    end
    assert_raises(ArgumentError, "Not odd") {
      oddclass.new(odd: 0)
    }
    odd = oddclass.new(odd: 1)
    assert_raises(ArgumentError, "Not odd") {
      odd.with(odd: 2)
    }
  end

  def test_memberless
    klass = MyData.define

    test = klass.new

    assert_equal(klass.new, test)
    refute_equal(MyData.define.new, test)

    assert_equal('#<data >', test.inspect)
    assert_equal([], test.members)
    assert_equal({}, test.to_h)
  end

  def test_dup
    skip
    klass = MyData.define(:foo, :bar)
    test = klass.new(foo: 1, bar: 2)
    assert_equal(klass.new(foo: 1, bar: 2), test.dup)
    assert_predicate(test.dup, :frozen?)
  end

  Klass = MyData.define(:foo, :bar)

  def test_marshal
    skip
    test = Klass.new(foo: 1, bar: 2)
    loaded = Marshal.load(Marshal.dump(test))
    assert_equal(test, loaded)
    refute_same(test, loaded)
    assert_predicate(loaded, :frozen?)
  end
end
