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
