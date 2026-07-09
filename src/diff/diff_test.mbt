// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.

test "identical sequences" {
  let a = ["a", "b", "c"]
  let d = diff(a, a)
  assert_true(to_old(d) == a)
  assert_true(to_new(d) == a)
  let mut non_equal = 0
  for c in d {
    match c {
      Equal(_) => ()
      _ => non_equal = non_equal + 1
    }
  }
  assert_eq(non_equal, 0)
}

test "simple insert" {
  let a = ["a", "b", "c"]
  let b = ["a", "b", "x", "c"]
  let d = diff(a, b)
  assert_true(to_new(d) == b)
  assert_true(to_old(d) == a)
}

test "simple delete" {
  let a = ["a", "b", "c", "d"]
  let b = ["a", "c", "d"]
  let d = diff(a, b)
  assert_true(to_new(d) == b)
  assert_true(to_old(d) == a)
}

test "replace block" {
  let a = ["1", "2", "3", "4", "5"]
  let b = ["1", "x", "y", "5"]
  let d = diff(a, b)
  assert_true(to_new(d) == b)
  assert_true(to_old(d) == a)
}

test "myers matches reconstruction" {
  let a = ["a", "b", "c", "d", "e", "f"]
  let b = ["a", "B", "c", "d", "x", "f"]
  let d = myers_diff(a, b)
  assert_true(to_new(d) == b)
  assert_true(to_old(d) == a)
}

test "myers vs lcs equivalence on reconstruction" {
  let a = ["the", "quick", "brown", "fox", "jumps"]
  let b = ["the", "slow", "brown", "fox", "sleeps"]
  assert_true(to_new(myers_diff(a, b)) == to_new(diff(a, b)))
}

test "unified round trip" {
  let old = "line1\nline2\nline3\nline4\nline5"
  let new = "line1\nLINE2\nline3\nline4\nline5x"
  let patch = to_unified(diff_lines(old, new), "old.txt", "new.txt", 3)
  assert_eq(apply_unified(old, patch), new)
}

test "empty sequences" {
  let a: Array[String] = []
  let d = diff(a, a)
  assert_eq(d.length(), 0)
  assert_eq(to_unified(d, "a", "b", 3), "")
}

test "character diff" {
  let old = "kitten"
  let new = "sitting"
  let ch = diff_chars(old, new)
  assert_eq(changes_to_string(ch), new)
  assert_true(to_old(ch).join("") == old)
}

test "token diff preserves whitespace" {
  let a = "the cat sat on the mat"
  let b = "the dog sat on a mat"
  let ch = diff_tokens(a, b)
  assert_eq(changes_to_string(ch), b)
  assert_true(to_old(ch).join("") == a)
}

test "reverse apply recovers old (patch -R)" {
  let old = "line1\nline2\nline3\nline4\nline5"
  let new = "line1\nLINE2\nline3\nline4\nline5x"
  let patch = to_unified(diff_lines(old, new), "old.txt", "new.txt", 3)
  assert_eq(apply_unified(old, patch), new)
  assert_eq(apply_unified_reverse(new, patch), old)
}

test "reverse_unified then forward apply" {
  let old = "a\nb\nc\nd"
  let new = "a\nB\nc\nd\nd2"
  let patch = to_unified(diff_lines(old, new), "a", "b", 3)
  let rev = reverse_unified(patch)
  assert_eq(apply_unified(new, rev), old)
}

test "sha1 known vectors" {
  assert_eq(sha1_hex(""), "da39a3ee5e6b4b0d3255bfef95601890afd80709")
  assert_eq(sha1_hex("abc"), "a9993e364706816aba3e25717850c26c9cd0d89d")
  assert_eq(
    sha1_hex("The quick brown fox jumps over the lazy dog"),
    "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12"
  )
  // 56-byte input: forces the two-block padding path
  assert_eq(
    sha1_hex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    "84983e441c3bd26ebaae4aa1f95129e5e54670f1"
  )
}

test "git diff text round trips" {
  let old = "foo\nbar\nbaz\n"
  let new = "foo\nBAR\nbaz\nqux\n"
  let patch = git_diff_text(old, new, "a/file.txt", "b/file.txt", 3)
  // the git extras (diff --git / index) are ignored by apply_unified
  assert_eq(apply_unified(old, patch), new)
  assert_eq(git_blob_hash(old).length(), 40)
}

test "binary diff format" {
  let patch = binary_diff("old bytes", "new bytes", "data.bin")
  assert_eq(patch.contains("Binary files a/data.bin and b/data.bin differ"), true)
  assert_eq(patch.contains("index "), true)
}

test "git_diff_text header structure" {
  // Pins the git header *layout* (the `diff --git` line and the `index
  // <old>..<new> 100644` line). The hash values themselves are locked by
  // "git blob hash matches git for utf8"; here we guard against anyone
  // breaking the surrounding decoration (dropping `100644`, changing the
  // `..` separator, or mis-wiring the a//b path) which the round-trip and
  // hash tests would all silently miss.
  let old = "foo\nbar\nbaz\n"
  let new = "foo\nBAR\nbaz\nqux\n"
  let patch = git_diff_text(old, new, "file.txt", "file.txt", 3)
  let oh = git_blob_hash(old)
  let nh = git_blob_hash(new)
  let header = "diff --git a/file.txt b/file.txt\n" +
    "index " + oh + ".." + nh + " 100644\n"
  assert_eq(patch.contains(header), true)
}

test "binary_diff header structure" {
  // A binary diff is fully deterministic, so we pin the *entire* output.
  let patch = binary_diff("old bytes", "new bytes", "data.bin")
  let oh = git_blob_hash("old bytes")
  let nh = git_blob_hash("new bytes")
  let expected = "diff --git a/data.bin b/data.bin\n" +
    "index " + oh + ".." + nh + " 100644\n" +
    "Binary files a/data.bin and b/data.bin differ\n"
  assert_eq(patch, expected)
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
  assert_eq(got, new)
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
  assert_eq(got, new)
}

test "fuzzy apply fails when tolerance exceeded" {
  let old = "a\nb\nc\nd\ne"
  let patch = "@@ -1,3 +1,3 @@\n x\n-y\n+Z\n z\n"
  let ok =
    match apply_unified_fuzzy(old, patch, 0, 0) {
      Ok(_) => true
      Err(_) => false
    }
  assert_eq(ok, false)
}

test "word_diff intra-line highlight" {
  let s = word_diff("the cat sat on the mat", "the dog sat on a mat")
  // insertions and deletions are interleaved by the token diff
  assert_eq(s, "the {+dog+}[-cat-] sat on {+a+}[-the-] mat")
}

test "word_diff_html marks del and ins" {
  let (o, n) = word_diff_html("the cat sat", "the dog sat")
  assert_eq(o, "the <del>cat</del> sat")
  assert_eq(n, "the <ins>dog</ins> sat")
}

test "merge3 clean non-overlapping" {
  let base = "1\n2\n3"
  let ours = "1\n2\n3\n4"
  let theirs = "0\n1\n2\n3"
  let (merged, n) = merge3_count(base, ours, theirs)
  assert_eq(merged, "0\n1\n2\n3\n4")
  assert_eq(n, 0)
}

test "merge3 emits conflict markers" {
  let base = "1\n2\n3\n4\n5"
  let ours = "1\n2\nX\n4\n5"
  let theirs = "1\n2\nY\n4\n5"
  let r = merge3(split_lines(base), split_lines(ours), split_lines(theirs))
  assert_eq(r.has_conflict, true)
  let merged = r.merged.join("\n")
  assert_eq(merged.contains("<<<<<<< ours"), true)
  assert_eq(merged.contains(">>>>>>> theirs"), true)
}

test "merge3 resolve ours drops markers" {
  let base = "1\n2\n3\n4\n5"
  let ours = "1\n2\nX\n4\n5"
  let theirs = "1\n2\nY\n4\n5"
  let r = merge3(split_lines(base), split_lines(ours), split_lines(theirs))
  let resolved = merge3_resolve_ours(r).join("\n")
  assert_eq(resolved.contains("<<<<<<<"), false)
  assert_eq(resolved.contains(">>>>>>>"), false)
  assert_eq(resolved.contains("X"), true)
}

test "all algorithms reconstruct" {
  let a = ["the", "quick", "brown", "fox"]
  let b = ["the", "slow", "red", "fox", "here"]
  let algos = [
    diff_algorithm_by_name("lcs"),
    diff_algorithm_by_name("myers"),
    diff_algorithm_by_name("patience"),
    diff_algorithm_by_name("histogram"),
    diff_algorithm_by_name("linear"),
  ]
  for algo in algos {
    let ch = diff_algorithm(algo, a, b)
    assert_true(to_new(ch) == b)
    assert_true(to_old(ch) == a)
  }
}

test "json diff produces patch" {
  let patch = match json_diff_text("{\"a\":1}", "{\"a\":2}") {
    Ok(s) => s
    Err(_) => "ERR"
  }
  assert_eq(patch.contains("\"op\":\"replace\""), true)
  assert_eq(patch.contains("/a"), true)
}

test "parse_json ok and fail" {
  assert_eq(parse_json("{\"x\":[1,true,null]}") is Ok(_), true)
  assert_eq(parse_json("not json") is Ok(_), false)
}

test "json round trip equal" {
  let j = match parse_json("{\"x\":[1,true,null]}") {
    Ok(v) => v
    Err(_) => json_null()
  }
  let s = json_to_string(j)
  let j2 = match parse_json(s) { Ok(v) => v; Err(_) => json_null() }
  assert_eq(json_equal(j, j2), true)
}

test "tree diff and patch apply round trip" {
  let old_fs = [("a.txt", "1\n2\n3"), ("b.txt", "x\ny")]
  let new_fs = [("a.txt", "1\n2\n3\n4"), ("c.txt", "hello")]
  let patch = render_tree_patch(old_fs, new_fs, 50)
  match apply_tree_patch(old_fs, patch) {
    Ok(result) => {
      let mut has_a = false
      let mut has_c = false
      let mut has_b = false
      for p in result {
        if p.0 == "a.txt" && p.1 == "1\n2\n3\n4" {
          has_a = true
        }
        if p.0 == "c.txt" {
          has_c = true
        }
        if p.0 == "b.txt" {
          has_b = true
        }
      }
      assert_eq(has_a, true)
      assert_eq(has_c, true)
      assert_eq(has_b, false)
    }
    Err(_) => assert_eq(1, 2)
  }
}

test "tree diff summary" {
  let old_fs = [("a.txt", "1\n2\n3")]
  let new_fs = [("a.txt", "1\n2\n3\n4"), ("b.txt", "x")]
  let td = diff_trees(old_fs, new_fs, 50)
  let s = tree_diff_summary(td)
  assert_eq(s.contains("files changed"), true)
}

test "tree diff add file with trailing newline round trips" {
  let old_fs: Array[(String, String)] = []
  let new_fs = [("new.txt", "hello\nworld\n")]
  let patch = render_tree_patch(old_fs, new_fs, 50)
  match apply_tree_patch(old_fs, patch) {
    Ok(result) => {
      let mut found = false
      for p in result {
        if p.0 == "new.txt" && p.1 == "hello\nworld\n" {
          found = true
        }
      }
      assert_eq(found, true)
    }
    Err(_) => assert_eq(1, 2)
  }
}

test "new file patch has git-conformant zero old count" {
  // A brand-new file has no old lines, so the hunk header must be
  // `@@ -1,0 +1,N @@` (0 old lines). The naive `diff_lines("", nc)` produces a
  // phantom trailing context line and yields a malformed `@@ -1,1 +1,0 @@`
  // (claims 0 added lines yet has `+` lines) that `git apply` / `patch` reject.
  let new_fs = [("new.txt", "abc\n")]
  let patch = render_tree_patch([], new_fs, 50)
  assert_eq(patch.contains("@@ -1,0 +1,"), true)
  assert_eq(patch.contains("@@ -1,1 +1,0 @@"), false)
}

test "tree diff rename with content change round trips" {
  let old_fs = [("old.txt", "line1\nline2\nline3\n")]
  let new_fs = [("new.txt", "line1\nCHANGED\nline3\n")]
  let patch = render_tree_patch(old_fs, new_fs, 50)
  match apply_tree_patch(old_fs, patch) {
    Ok(result) => {
      let mut has_new = false
      let mut has_old = false
      for p in result {
        if p.0 == "new.txt" && p.1 == "line1\nCHANGED\nline3\n" {
          has_new = true
        }
        if p.0 == "old.txt" {
          has_old = true
        }
      }
      assert_eq(has_new, true)
      assert_eq(has_old, false)
    }
    Err(_) => assert_eq(1, 2)
  }
}

test "git blob hash matches git for utf8" {
  // Reference values produced by `git hash-object` (SHA-1 of
  // "blob <byte-length>\0<content>" in UTF-8). ASCII and CJK both match.
  assert_eq(git_blob_hash("hello"), "b6fc4c620b67d95f953a5c1c1230aaab5db5a1b0")
  assert_eq(git_blob_hash("爱"), "f70fea1eca098e927a3ed1fb2a88ba067ba6e280")
  assert_eq(
    git_blob_hash("中文测试"),
    "a412086f6f4388a176d5cc095212fd09969b018a",
  )
}

test "unified_to_html marks ins and del" {
  let html = unified_to_html("a\nb", "a\nB", 3)
  assert_eq(html.contains("class=\"ins\""), true)
  assert_eq(html.contains("class=\"del\""), true)
  assert_eq(html.contains("<table"), true)
  let page = diff_html_page("a\nb", "a\nB", 3, "My Diff")
  assert_eq(page.contains("<html>"), true)
  assert_eq(page.contains("class=\"ins\""), true)
}

test "prefix/suffix pruning preserves round-trip for all algorithms" {
  // A large common prefix and suffix with only the middle changed. The trimming
  // optimization must leave the reconstructed inputs byte-for-byte identical for
  // every algorithm (the trimmed lines are always `Equal`).
  let a = [
    "keep", "keep", "keep", "keep", "keep", "keep", "keep", "keep", "keep",
    "OLD", "mid", "x",
    "tail", "tail", "tail", "tail", "tail", "tail", "tail", "tail", "tail",
  ]
  let b = [
    "keep", "keep", "keep", "keep", "keep", "keep", "keep", "keep", "keep",
    "NEW", "mid", "y",
    "tail", "tail", "tail", "tail", "tail", "tail", "tail", "tail", "tail",
  ]
  let names = ["lcs", "myers", "patience", "histogram", "linear"]
  for name in names {
    let ch = diff_algorithm(diff_algorithm_by_name(name), a, b)
    assert_true(to_old(ch) == a)
    assert_true(to_new(ch) == b)
  }
}

test "unified stat summary format" {
  let ch = diff_lines("a\nb\nc", "a\nB\nc\nd")
  // one delete (b -> B) + one insert (d) == 2 changed lines
  let s = to_unified_stat(ch, "f.txt", 40)
  assert_eq(s, "f.txt | 2 +-")
  let none = diff_lines("x\ny", "x\ny")
  assert_eq(to_unified_stat(none, "g.txt", 40), "g.txt | 0")
}

test "unified stat histogram scales large changes" {
  let mut old = ""
  let mut new = ""
  for i = 0; i < 100; i = i + 1 {
    old = old + "o\n"
    new = new + "n\n"
  }
  let ch = diff_lines(old, new)
  let s = to_unified_stat(ch, "big.txt", 40)
  // 200 changes -> the +/- bar is exactly `stat_width` (= 40) columns
  let prefix = "big.txt | 200 "
  assert_eq(s.length() - prefix.length(), 40)
}

test "ignore whitespace and case reports no spurious changes" {
  let ch = diff_lines_ignore("a B c", "A  b  C", true, true)
  let mut diffs = 0
  for c in ch {
    match c {
      Equal(_) => ()
      _ => diffs = diffs + 1
    }
  }
  assert_eq(diffs, 0)
}

test "ignore whitespace still catches real content changes" {
  let ch = diff_lines_ignore("foo bar", "foo baz", true, false)
  let mut diffs = 0
  for c in ch {
    match c {
      Equal(_) => ()
      _ => diffs = diffs + 1
    }
  }
  // bar -> baz is a real content change: one delete + one insert
  assert_eq(diffs, 2)
}
