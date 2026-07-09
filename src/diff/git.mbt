// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.

/// 32-bit rotate-left helpers (MoonBit `Int` is 32-bit; `>>` is arithmetic,
/// so we mask the right-shifted part to emulate a logical shift).
// All SHA-1 math is mod 2^32. MoonBit `Int` may be wider than 32 bits, so we
// mask after every arithmetic/shift to keep values in the low 32 bits. On a
// true 32-bit `Int` this is a no-op (0xffffffff == -1).
fn mask32(x: Int) -> Int {
  x & 0xffffffff
}
fn rotl1(x: Int) -> Int {
  mask32((x << 1) | ((x >> 31) & 0x1))
}
fn rotl5(x: Int) -> Int {
  mask32((x << 5) | ((x >> 27) & 0x1f))
}
fn rotl30(x: Int) -> Int {
  mask32((x << 30) | ((x >> 2) & 0x3fffffff))
}

/// SHA-1 over a sequence of bytes stored as `Int` (each in 0..255).
fn sha1(msg: Array[Int]) -> Array[Int] {
  let bit_len = msg.length() * 8
  let data: Array[Int] = []
  for b in msg {
    data.push(b)
  }
  data.push(0x80)
  while data.length() % 64 != 56 {
    data.push(0)
  }
  // append 64-bit big-endian bit length (high 32 bits are 0 for our inputs)
  data.push(0)
  data.push(0)
  data.push(0)
  data.push(0)
  data.push((bit_len >> 24) & 0xff)
  data.push((bit_len >> 16) & 0xff)
  data.push((bit_len >> 8) & 0xff)
  data.push(bit_len & 0xff)

  let mut h0 = 0x67452301
  let mut h1 = 0xEFCDAB89
  let mut h2 = 0x98BADCFE
  let mut h3 = 0x10325476
  let mut h4 = 0xC3D2E1F0

  let mut i = 0
  while i < data.length() {
    let w: Array[Int] = Array::make(80, 0)
    for t = 0; t < 16; t = t + 1 {
      let base = i + t * 4
      w[t] = mask32(
        (data[base] << 24) | (data[base + 1] << 16) |
        (data[base + 2] << 8) | data[base + 3],
      )
    }
    for t = 16; t < 80; t = t + 1 {
      w[t] = rotl1(w[t - 3] ^ w[t - 8] ^ w[t - 14] ^ w[t - 16])
    }
    let mut a = h0
    let mut b = h1
    let mut c = h2
    let mut d = h3
    let mut e = h4
    for t = 0; t < 80; t = t + 1 {
      let nb = b ^ 0xffffffff
      let f = if t < 20 {
        (b & c) | (nb & d)
      } else if t < 40 {
        b ^ c ^ d
      } else if t < 60 {
        (b & c) | (b & d) | (c & d)
      } else {
        b ^ c ^ d
      }
      let k = if t < 20 {
        0x5A827999
      } else if t < 40 {
        0x6ED9EBA1
      } else if t < 60 {
        0x8F1BBCDC
      } else {
        0xCA62C1D6
      }
      let temp = mask32(rotl5(a) + e + f + k + w[t])
      e = d
      d = c
      c = rotl30(b)
      b = a
      a = temp
    }
    h0 = mask32(h0 + a)
    h1 = mask32(h1 + b)
    h2 = mask32(h2 + c)
    h3 = mask32(h3 + d)
    h4 = mask32(h4 + e)
    i = i + 64
  }
  [h0, h1, h2, h3, h4]
}

/// Renders SHA-1 words as a 40-character lowercase hex string.
fn to_hex(words: Array[Int]) -> String {
  let hex_chars = "0123456789abcdef"
  let out: Array[String] = []
  let nibbles = [28, 24, 20, 16, 12, 8, 4, 0]
  for w in words {
    for s in nibbles {
      let nibble = (w >> s) & 0xf
      out.push(String::from_array([hex_chars[nibble].to_int().unsafe_to_char()]))
    }
  }
  out.join("")
}

/// Encodes a string as its UTF-8 byte sequence, returned as `Int`s in 0..255.
/// A MoonBit `String` is indexed by *code point*, so each scalar must be
/// expanded to its UTF-8 bytes manually (1 byte for ASCII, 2/3/4 bytes for a
/// multibyte char). This is what makes `sha1_hex` / `git_blob_hash` correct for
/// Chinese, Japanese, Korean and any non-ASCII text.
fn utf8_bytes(s: String) -> Array[Int] {
  let out: Array[Int] = []
  let n = s.length()
  for i = 0; i < n; i = i + 1 {
    let cp = s[i].to_int()
    if cp < 0x80 {
      out.push(cp)
    } else if cp < 0x800 {
      out.push(0xc0 | (cp >> 6))
      out.push(0x80 | (cp & 0x3f))
    } else if cp < 0x10000 {
      out.push(0xe0 | (cp >> 12))
      out.push(0x80 | ((cp >> 6) & 0x3f))
      out.push(0x80 | (cp & 0x3f))
    } else {
      out.push(0xf0 | (cp >> 18))
      out.push(0x80 | ((cp >> 12) & 0x3f))
      out.push(0x80 | ((cp >> 6) & 0x3f))
      out.push(0x80 | (cp & 0x3f))
    }
  }
  out
}

/// SHA-1 (hex) of the UTF-8 bytes of `s` (correct for multibyte text).
pub fn sha1_hex(s: String) -> String {
  to_hex(sha1(utf8_bytes(s)))
}

/// Computes the git *blob* SHA-1 of a text file's content, i.e. the hash used
/// in a git `index` line. The result matches `git` for **any** UTF-8 content,
/// because the `blob <byte-length>\0` prefix uses the *byte* length and the
/// content is fed byte-by-byte in UTF-8 (not code-point) order.
pub fn git_blob_hash(text: String) -> String {
  let bytes = utf8_bytes(text)
  let msg: Array[Int] = []
  let prefix = "blob " + bytes.length().to_string()
  for i = 0; i < prefix.length(); i = i + 1 {
    msg.push(prefix[i].to_int() & 0xff)
  }
  msg.push(0)
  for b in bytes {
    msg.push(b)
  }
  to_hex(sha1(msg))
}

/// Builds the `diff --git a/X b/Y` header line shared by `git_diff_text`,
/// `binary_diff` and the file-level headers emitted by `dir.mbt`.
fn diff_git_line(a_path: String, b_path: String) -> String {
  "diff --git a/" + a_path + " b/" + b_path + "\n"
}

/// Builds the `index <old_sha>..<new_sha> 100644` line shared by `git_diff_text`
/// and `binary_diff`.
fn git_index_header(old_hash: String, new_hash: String) -> String {
  "index " + old_hash + ".." + new_hash + " 100644\n"
}

/// Renders a git-style unified diff with a `diff --git` header and an `index`
/// line carrying the blob SHA-1s (matching `git diff` output). Pass names such
/// as `"a/file.txt"` / `"b/file.txt"`.
pub fn git_diff_text(
  old_text: String,
  new_text: String,
  old_name: String,
  new_name: String,
  context: Int
) -> String {
  let changes = diff_lines(old_text, new_text)
  let body = to_unified(changes, old_name, new_name, context)
  let oh = git_blob_hash(old_text)
  let nh = git_blob_hash(new_text)
  diff_git_line(old_name, new_name) + git_index_header(oh, nh) + body
}

/// Produces a git-style binary diff (`Binary files ... differ`) with proper
/// blob SHA-1s in the `index` line.
pub fn binary_diff(old: String, new: String, name: String) -> String {
  let oh = git_blob_hash(old)
  let nh = git_blob_hash(new)
  diff_git_line(name, name) + git_index_header(oh, nh) +
  "Binary files a/" + name + " and b/" + name + " differ\n"
}
