defmodule SiteDeNormes.Transforms.HeaderSlugifierTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias SiteDeNormes.Transforms.HeaderSlugifier

  describe "slugify/2 - deduplication" do
    test "first occurrence has no suffix" do
      {slug, seen} = HeaderSlugifier.slugify("Hello World")
      assert slug == "hello-world"
      assert Map.has_key?(seen, "hello-world")
    end

    test "second occurrence gets -1 suffix" do
      {_slug1, seen} = HeaderSlugifier.slugify("Hello World")
      {slug2, _} = HeaderSlugifier.slugify("Hello World", seen)
      assert slug2 == "hello-world-1"
    end

    test "third occurrence gets -2 suffix" do
      {_s1, seen1} = HeaderSlugifier.slugify("Same Title")
      {s2, seen2} = HeaderSlugifier.slugify("Same Title", seen1)
      {s3, _} = HeaderSlugifier.slugify("Same Title", seen2)
      assert s2 == "same-title-1"
      assert s3 == "same-title-2"
    end

    test "different headings don't interfere with each other" do
      {_a, seen_a} = HeaderSlugifier.slugify("First")
      {b, seen_b} = HeaderSlugifier.slugify("Second", seen_a)
      {c, _} = HeaderSlugifier.slugify("First", seen_b)

      assert b == "second"
      assert c == "first-1"
    end

    test "suffix collision also gets another suffix" do
      {_s1, seen} = HeaderSlugifier.slugify("Title")
      {s2, seen_after} = HeaderSlugifier.slugify("Title", seen)
      # s2 is "title-1", now add "Title-1" which produces "title-1" after slugification
      {s3, _} = HeaderSlugifier.slugify("Title-1", seen_after)
      assert s2 == "title-1"
      assert s3 == "title-1-1"
    end

    test "empty string returns empty slug" do
      assert {"", %{}} = HeaderSlugifier.slugify("")
    end

    test "only special chars produces empty slug" do
      {_slug, seen} = HeaderSlugifier.slugify("!!!")
      # Empty slug is stored in seen to avoid re-use
      assert Map.has_key?(seen, "")
    end
  end

  describe "property-based Comrak match" do
    property "slugify matches MDEx.anchorize for any string" do
      # Build a generator that covers all Unicode ranges Comrak's anchorizer considers.
      # StreamData functions are imported by ExUnitProperties into the property body.
      text_gen =
        StreamData.frequency([
          {30, StreamData.string([?\s..?~], count: :codepoints)},
          {20, StreamData.string([0x00C0..0x024F], count: :codepoints)},
          {15,
           StreamData.one_of([
             # CJK
             StreamData.string([0x4E00..0x9FFF], count: :codepoints),
             StreamData.string([0x3040..0x30FF], count: :codepoints),
             # Arabic
             StreamData.string([0x0600..0x06FF], count: :codepoints),
             # Devanagari
             StreamData.string([0x0900..0x097F], count: :codepoints),
             # Greek
             StreamData.string([0x0370..0x03FF], count: :codepoints),
             # Cyrillic
             StreamData.string([0x0400..0x04FF], count: :codepoints),
             # Hebrew
             StreamData.string([0x0590..0x05FF], count: :codepoints)
           ])},
          {10,
           StreamData.one_of([
             # NBSP U+00A0
             StreamData.constant(160),
             # Thin space U+2009
             StreamData.constant(8201),
             # Narrow no-break space U+202F
             StreamData.constant(8239),
             # Medium mathematical space U+205F
             StreamData.constant(8287),
             # Ideographic space U+3000
             StreamData.constant(12288)
           ])
           |> StreamData.map(&List.to_string([&1]))},
          {10, StreamData.string([0x0300..0x036F], count: :codepoints)},
          {5,
           StreamData.one_of([
             # Miscellaneous Symbols and Pictographs
             StreamData.string([0x1F300..0x1F9FF], count: :codepoints),
             # Emoticons
             StreamData.string([0x1F600..0x1F64F], count: :codepoints),
             # Transport and Map Symbols
             StreamData.string([0x1F680..0x1F6FF], count: :codepoints)
           ])}
        ])
        |> StreamData.list_of(min_length: 0, max_length: 200)
        |> StreamData.map(&IO.chardata_to_string/1)

      check all(text <- text_gen) do
        {our_slug, _} = HeaderSlugifier.slugify(text)
        comrak_id = MDEx.anchorize(text)

        assert our_slug == comrak_id,
               "Mismatch for #{inspect(text)}\n  ours:   #{inspect(our_slug)}\n  Comrak: #{inspect(comrak_id)}"
      end
    end
  end
end
