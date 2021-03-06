defmodule RuleEngineLispTest do
  use ExUnit.Case

  @moduletag timeout: 500

  def assert_ok({:ok, _}), do: nil
  def assert_ok(e), do: assert false, "Should have parsed, but got #{inspect e}"

  def assert_error({:ok, _}), do: assert false, "Should not have parsed"
  def assert_error(_), do: nil

  def parse(v), do: RuleEngine.parse_lisp_value(v, :test)
  def parse_document(v), do: RuleEngine.parse_lisp(v, :test)


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

  test "post content bad line check" do
    lisp = "(hi hello world \r\n\"apples\r\nfruit\r\noranges\" 123 fruit cake)\r\n\r\nabc'efghi'j\"klm"
    res = parse(lisp)
    assert_error(res)
    {:error, _, origin} = res
    assert origin.line == 6
    assert origin.column == 3
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

  test "document with string and \\r\\n" do
    doc = "(hello)\r\n32\r\n;comment\r\n;comment\r\n\r\n(\"text\")\r\n; comment"
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

  test "parse jumbled number fails" do
    assert_error(parse("(123a5 34b98)"))
  end
end
