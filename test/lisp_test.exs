defmodule RuleEngineLispTest do
  use ExUnit.Case
  import RuleEngine.LISP
  require Logger

  @moduletag timeout: 500

  def assert_ok({:ok, _}), do: nil
  def assert_ok(e), do: assert false, "Should have parsed, but got #{inspect e}"

  def assert_error({:ok, _}), do: assert false, "Should not have parsed"
  def assert_error(_), do: nil


  test "hello world" do
    assert_ok(parse("(hello 123)"))
  end

  test "nested" do
    assert_ok(parse("(hello (bacon 123))"))
  end

  test "comments 1" do
    lisp = """
(hello ; Nothing here!
123)
    """
    assert_ok(parse(lisp))
  end

  test "comments 2" do
    lisp = """
(hello
; Nothing here!
123)
    """
    assert_ok(parse(lisp))
  end

  test "comments before" do
    lisp = """
;comments are fine before
(hello 123)
    """
    assert_ok(parse(lisp))
  end

  test "comments after" do
    lisp = """
(hello 123)
;comments are fine after
    """
    assert_ok(parse(lisp))
  end

  test "comments before and after" do
    lisp = """
;comments are fine before
(hello 123)
;comments are fine after
    """
    assert_ok(parse(lisp))
  end

  test "spacing 1" do
    lisp = """

(hello 123)
    """
    assert_ok(parse(lisp))
  end

  test "spacing 2" do
    lisp = """
    (hello 123)
    """
    assert_ok(parse(lisp))
  end

  test "spacing 3" do
    lisp = """
    (hello 123)

    """
    assert_ok(parse(lisp))
  end

  test "spacing 4" do
    lisp = """

    \t(  hello      123   )

    """
    assert_ok(parse(lisp))
  end

  test "post content is bad" do
    lisp = """
(hello 123)
This should cause an error
    """
    assert_error(parse(lisp))
  end

  test "pre content is bad" do
    lisp = """
This should cause an error
(hello 123)
    """
    assert_error(parse(lisp))
  end

  test "missing end paren" do
    assert_error(parse("(hello 123"))
  end

  test "missing start" do
    assert_error(parse("hello 123)"))
  end

  test "missing end map" do
    assert_error(parse("%{hello 123"))
  end

  test "missing start map" do
    assert_error(parse("hello 123}"))
  end

  test "quoting parses" do
    assert_ok(parse("(hello 'keyword)"))
    assert_ok(parse("(hello '(1 2 3))"))
  end

  test "double quoting parses" do
    assert_ok(parse("(hello ''keyword)"))
  end

  test "double document" do
    doc = """
(thing thang)
; comments

; empty space
(mumbo jumbo)
    """
    assert_ok(parse_document(doc))
  end

  test "parse document without document" do
    doc = """
(thing thang)
; comments

; empty space
(mumbo jumbo)
    """
    assert_error(parse(doc))
  end
end
