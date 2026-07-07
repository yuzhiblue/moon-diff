// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.

test "identical sequences" {
  let a = ["a", "b", "c"]
  let d = diff(a, a)
  assert_eq!(to_old(d), a)
  assert_eq!(to_new(d), a)
  let mut non_equal = 0
  for c in d {
    match c {
      Equal(_) => ()
      _ => non_equal = non_equal + 1
    }
  }
  assert_eq!(non_equal, 0)
}

test "simple insert" {
  let a = ["a", "b", "c"]
  let b = ["a", "b", "x", "c"]
  let d = diff(a, b)
  assert_eq!(to_new(d), b)
  assert_eq!(to_old(d), a)
}

test "simple delete" {
  let a = ["a", "b", "c", "d"]
  let b = ["a", "c", "d"]
  let d = diff(a, b)
  assert_eq!(to_new(d), b)
  assert_eq!(to_old(d), a)
}

test "replace block" {
  let a = ["1", "2", "3", "4", "5"]
  let b = ["1", "x", "y", "5"]
  let d = diff(a, b)
  assert_eq!(to_new(d), b)
  assert_eq!(to_old(d), a)
}

test "myers matches reconstruction" {
  let a = ["a", "b", "c", "d", "e", "f"]
  let b = ["a", "B", "c", "d", "x", "f"]
  let d = myers_diff(a, b)
  assert_eq!(to_new(d), b)
  assert_eq!(to_old(d), a)
}

test "myers vs lcs equivalence on reconstruction" {
  let a = ["the", "quick", "brown", "fox", "jumps"]
  let b = ["the", "slow", "brown", "fox", "sleeps"]
  assert_eq!(to_new(myers_diff(a, b)), to_new(diff(a, b)))
}

test "unified round trip" {
  let old = "line1\nline2\nline3\nline4\nline5"
  let new = "line1\nLINE2\nline3\nline4\nline5x"
  let patch = to_unified(diff_lines(old, new), "old.txt", "new.txt", 3)
  assert_eq!(apply_unified(old, patch), new)
}

test "empty sequences" {
  let a: Array[String] = []
  let d = diff(a, a)
  assert_eq!(d.length(), 0)
  assert_eq!(to_unified(d, "a", "b", 3), "")
}

test "character diff" {
  let old = "kitten"
  let new = "sitting"
  let ch = diff_chars(old, new)
  assert_eq!(changes_to_string(ch), new)
  assert_eq!(to_old(ch).join(""), old)
}

test "token diff preserves whitespace" {
  let a = "the cat sat on the mat"
  let b = "the dog sat on a mat"
  let ch = diff_tokens(a, b)
  assert_eq!(changes_to_string(ch), b)
  assert_eq!(to_old(ch).join(""), a)
}

test "reverse apply recovers old (patch -R)" {
  let old = "line1\nline2\nline3\nline4\nline5"
  let new = "line1\nLINE2\nline3\nline4\nline5x"
  let patch = to_unified(diff_lines(old, new), "old.txt", "new.txt", 3)
  assert_eq!(apply_unified(old, patch), new)
  assert_eq!(apply_unified_reverse(new, patch), old)
}

test "reverse_unified then forward apply" {
  let old = "a\nb\nc\nd"
  let new = "a\nB\nc\nd\nd2"
  let patch = to_unified(diff_lines(old, new), "a", "b", 3)
  let rev = reverse_unified(patch)
  assert_eq!(apply_unified(new, rev), old)
}

test "sha1 known vectors" {
  assert_eq!(sha1_hex(""), "da39a3ee5e6b4b0d3255bfef95601890afd80709")
  assert_eq!(sha1_hex("abc"), "a9993e364706816aba3e25717850c26c9cd0d89d")
  assert_eq!(
    sha1_hex("The quick brown fox jumps over the lazy dog"),
    "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12"
  )
  // 56-byte input: forces the two-block padding path
  assert_eq!(
    sha1_hex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    "84983e441c3bd26ebaae4aa1f95129e5e54670f1"
  )
}

test "git diff text round trips" {
  let old = "foo\nbar\nbaz\n"
  let new = "foo\nBAR\nbaz\nqux\n"
  let patch = git_diff_text(old, new, "a/file.txt", "b/file.txt", 3)
  // the git extras (diff --git / index) are ignored by apply_unified
  assert_eq!(apply_unified(old, patch), new)
  assert_eq!(git_blob_hash(old).length(), 40)
}

test "binary diff format" {
  let patch = binary_diff("old bytes", "new bytes", "data.bin")
  assert_eq!(patch.contains("Binary files a/data.bin and b/data.bin differ"), true)
  assert_eq!(patch.contains("index "), true)
}

test "fuzzy apply with offset" {
  let old = "a\nb\nc\nd\ne\nf\ng"
  let new = "a\nb\nc\nd\nX\nf\ng"
  // patch claims the change is at line 7, but it is really at line 5
  let patch =
    "@@ -7,3 +7,3 @@\n d\n-e\n+X\n f\n"
  let got =
    match apply_unified_fuzzy(old, patch, 0, 3) {
      Ok(x) => x
      Err(m) => m
    }
  assert_eq!(got, new)
}

test "fuzzy apply with fuzz" {
  // first context line is stale ("ONE"); core still matches with fuzz
  let old = "one\ntwo\nthree\nfour\nfive"
  let new = "one\nTWO\nthree\nfour\nfive"
  let patch =
    "@@ -1,5 +1,5 @@\n ONE\n-two\n+TWO\n three\n four\n five\n"
  let got =
    match apply_unified_fuzzy(old, patch, 2, 0) {
      Ok(x) => x
      Err(m) => m
    }
  assert_eq!(got, new)
}

test "fuzzy apply fails when tolerance exceeded" {
  let old = "a\nb\nc\nd\ne"
  let patch = "@@ -1,3 +1,3 @@\n x\n-y\n+Z\n z\n"
  let ok =
    match apply_unified_fuzzy(old, patch, 0, 0) {
      Ok(_) => true
      Err(_) => false
    }
  assert_eq!(ok, false)
}

test "word_diff intra-line highlight" {
  let s = word_diff("the cat sat on the mat", "the dog sat on a mat")
  // insertions and deletions are interleaved by the token diff
  assert_eq!(s, "the {+dog+}[-cat-] sat on {+a+}[-the-] mat")
}

test "word_diff_html marks del and ins" {
  let (o, n) = word_diff_html("the cat sat", "the dog sat")
  assert_eq!(o, "the <del>cat</del> sat")
  assert_eq!(n, "the <ins>dog</ins> sat")
}

