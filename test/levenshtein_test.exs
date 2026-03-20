defmodule Calque.LevenshteinTest do
  use ExUnit.Case, async: true
  alias Calque.Levenshtein

  describe "distance/2" do
    test "identical strings return 0" do
      assert Levenshtein.distance("review", "review") == 0
      assert Levenshtein.distance("", "") == 0
    end

    test "empty to string equals string length" do
      assert Levenshtein.distance("", "hello") == 5
    end

    test "string to empty equals string length" do
      assert Levenshtein.distance("hello", "") == 5
    end

    test "single insertion" do
      assert Levenshtein.distance("abc", "abcd") == 1
    end

    test "single deletion" do
      assert Levenshtein.distance("abcd", "abc") == 1
    end

    test "single substitution" do
      assert Levenshtein.distance("abc", "axc") == 1
    end

    test "transposition costs 2 (not transposition-aware)" do
      assert Levenshtein.distance("ab", "ba") == 2
    end

    test "completely different strings" do
      assert Levenshtein.distance("abc", "xyz") == 3
    end

    test "counts unicode graphemes, not bytes" do
      # "é" is one grapheme — substituting it for "e" costs 1, not 2
      assert Levenshtein.distance("café", "cafe") == 1
      assert Levenshtein.distance("", "é") == 1
    end

    test "typical command typos stay within the fuzzy-match threshold of 3" do
      assert Levenshtein.distance("reviwe", "review") <= 3
      assert Levenshtein.distance("accpet-all", "accept-all") <= 3
      assert Levenshtein.distance("rject-all", "reject-all") <= 3
    end

    test "very different commands exceed the threshold" do
      assert Levenshtein.distance("review", "accept-all") > 3
    end
  end
end
