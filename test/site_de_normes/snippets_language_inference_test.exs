defmodule SiteDeNormes.SnippetsLanguageInferenceTest do
  use ExUnit.Case, async: true

  alias SiteDeNormes.SnippetsLanguageInference

  describe "detect_language/1" do
    test "detects XML declaration" do
      assert SnippetsLanguageInference.detect_language("<?xml version=\"1.0\"?>") == :xml
    end

    test "detects DTD declarations" do
      assert SnippetsLanguageInference.detect_language("<!DOCTYPE root>") == :xml
      assert SnippetsLanguageInference.detect_language("<!ELEMENT root ANY>") == :xml
    end

    test "detects matching opening and closing tags" do
      assert SnippetsLanguageInference.detect_language("<root><child/></root>") == :xml
      assert SnippetsLanguageInference.detect_language("<a>text</a>") == :xml
    end

    test "ignores unmatched tags (no matching closing tag)" do
      refute SnippetsLanguageInference.detect_language("<foo><bar></baz>") == :xml
    end

    test "ignores plain text" do
      refute SnippetsLanguageInference.detect_language("hello world") == :xml
    end

    test "ignores code with no tags" do
      refute SnippetsLanguageInference.detect_language("def hello\n  puts 'world'\nend") == :xml
    end

    test "ignores self-closing-only content (no matching pair)" do
      refute SnippetsLanguageInference.detect_language("<foo/><bar/>") == :xml
    end
  end

  describe "attach/1 + step" do
    defp document(markdown) do
      MDEx.new(markdown: markdown)
      |> SiteDeNormes.SnippetsLanguageInference.attach()
      |> MDEx.Document.run()
    end

    test "labels unlabelled XML code blocks with xml language" do
      doc =
        document("""
        ```
        <root><child/></root>
        ```
        """)

      code_blocks = doc[MDEx.CodeBlock]
      assert length(code_blocks) == 1
      assert hd(code_blocks).info == "xml"
    end

    test "does not modify already-labelled code blocks" do
      doc =
        document("""
        ```elixir
        def hello, do: :world
        ```
        """)

      code_blocks = doc[MDEx.CodeBlock]
      assert length(code_blocks) == 1
      assert hd(code_blocks).info == "elixir"
    end

    test "does not modify unlabelled blocks that are not XML" do
      doc =
        document("""
        ```
        def hello\n  puts 'world'\nend
        ```
        """)

      code_blocks = doc[MDEx.CodeBlock]
      assert length(code_blocks) == 1
      assert hd(code_blocks).info == ""
    end

    test "renders XML-highlighted output in HTML" do
      html =
        document("""
        ```
        <root><child/></root>
        ```
        """)
        |> MDEx.to_html!()

      assert html =~ "language-xml"
    end

    test "handles multiple code blocks, only labelling XML ones" do
      doc =
        document("""
        ```
        <config><setting name="x" value="1"/></config>
        ```

        ```elixir
        defmodule Foo do; end
        ```

        ```
        plain text with no tags
        ```
        """)

      code_blocks = doc[MDEx.CodeBlock]
      assert length(code_blocks) == 3

      assert hd(code_blocks).info == "xml"
      assert Enum.at(code_blocks, 1).info == "elixir"
      assert Enum.at(code_blocks, 2).info == ""
    end
  end
end
