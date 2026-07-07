// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.

/// One classified change between two file trees.
pub enum FileChange {
  /// A new file appeared at `path` with `content`.
  Added(String, String)
  /// A file at `path` with `content` disappeared.
  Removed(String, String)
  /// `path` changed from `old` to `new`.
  Modified(String, String, String)
  /// A file was renamed from `from` to `to` (content similarity above threshold).
  Renamed(String, String)
}

/// The full set of changes between two trees.
pub struct TreeDiff {
  pub changes: Array[FileChange]
}

/// Builds a deterministic (path-sorted) file set from raw `(path, content)` pairs.
pub fn fileset(pairs: Array[(String, String)]) -> Array[(String, String)] {
  let out: Array[(String, String)] = []
  for p in pairs {
    out.push(p)
  }
  for i = 1; i < out.length(); i = i + 1 {
    let mut j = i
    while j > 0 && out[j - 1].0 > out[j].0 {
      let tmp = out[j - 1]
      out[j - 1] = out[j]
      out[j] = tmp
      j = j - 1
    }
  }
  out
}

/// Looks up a file's content by path, or `None` if absent.
fn fileset_get(
  fs: Array[(String, String)],
  path: String
) -> Option[String] {
  for p in fs {
    if p.0 == path {
      return Some(p.1)
    }
  }
  None
}

/// Line-based similarity (git's metric): `2 * common / (|a| + |b|)`, as a
/// percentage. Two identical files score 100; disjoint files score 0.
fn similarity(old: String, new: String) -> Int {
  let a = split_lines(old)
  let b = split_lines(new)
  if a.length() == 0 && b.length() == 0 {
    return 100
  }
  let cnt: Array[(String, Int)] = []
  for x in b {
    imap_inc(cnt, x)
  }
  let seen: Array[(String, Int)] = []
  let mut common = 0
  for x in a {
    let avail = imap_get(cnt, x)
    let used = imap_get(seen, x)
    if avail > used {
      common = common + 1
      imap_set(seen, x, used + 1)
    }
  }
  if a.length() + b.length() == 0 {
    100
  } else {
    (2 * common * 100) / (a.length() + b.length())
  }
}

/// Greedy rename detection: pairs each removed file with the most similar added
/// file whose similarity is at least `threshold`%. Returns the renames plus the
/// removed/added files that could not be paired.
fn detect_renames(
  removed: Array[(String, String)],
  added: Array[(String, String)],
  threshold: Int
) -> (
  Array[FileChange],
  Array[(String, String)],
  Array[(String, String)]
) {
  let renames: Array[FileChange] = []
  let rem_removed: Array[(String, String)] = []
  let used_added: Array[(Int, Int)] = []
  for r in removed {
    let (from, oc) = r
    let mut best_idx = -1
    let mut best_sim = threshold - 1
    for ai = 0; ai < added.length(); ai = ai + 1 {
      let already = imap_get(used_added, ai)
      if already > 0 {
        continue
      }
      let (_, nc) = added[ai]
      let sim = similarity(oc, nc)
      if sim > best_sim {
        best_sim = sim
        best_idx = ai
      }
    }
    if best_idx >= 0 {
      imap_set(used_added, best_idx, 1)
      let (to, _) = added[best_idx]
      renames.push(Renamed(from, to))
    } else {
      rem_removed.push(r)
    }
  }
  let rem_added: Array[(String, String)] = []
  for ai = 0; ai < added.length(); ai = ai + 1 {
    let used = imap_get(used_added, ai)
    if used == 0 {
      rem_added.push(added[ai])
    }
  }
  (renames, rem_removed, rem_added)
}

/// Computes the structural diff between two file trees. `threshold` is the
/// minimum similarity (percent) to report a deletion+addition as a rename.
pub fn diff_trees(
  old_fs: Array[(String, String)],
  new_fs: Array[(String, String)],
  threshold: Int
) -> TreeDiff {
  let removed: Array[(String, String)] = []
  let added: Array[(String, String)] = []
  let modified: Array[FileChange] = []
  for p in old_fs {
    match fileset_get(new_fs, p.0) {
      Some(nc) => {
        if p.1 != nc {
          modified.push(Modified(p.0, p.1, nc))
        }
      }
      None => removed.push(p)
    }
  }
  for p in new_fs {
    match fileset_get(old_fs, p.0) {
      None => added.push(p)
      Some(_) => ()
    }
  }
  let (renames, rem_removed, rem_added) =
    detect_renames(removed, added, threshold)
  let changes: Array[FileChange] = []
  for c in modified {
    changes.push(c)
  }
  for c in renames {
    changes.push(c)
  }
  for p in rem_removed {
    changes.push(Removed(p.0, p.1))
  }
  for p in rem_added {
    changes.push(Added(p.0, p.1))
  }
  TreeDiff::{ changes }
}

/// Strips a leading `a/` or `b/` (or `dev/null`) from a git path component.
fn strip_dir(s: String) -> String {
  if substring(s, 0, 2) == "a/" {
    substring(s, 2, s.length())
  } else if substring(s, 0, 2) == "b/" {
    substring(s, 2, s.length())
  } else {
    s
  }
}

/// Renders a single change as a Git-style patch fragment. `old_fs`/`new_fs` are
/// needed to recover file contents for renames.
fn render_change(
  c: FileChange,
  old_fs: Array[(String, String)],
  new_fs: Array[(String, String)]
) -> String {
  match c {
    Modified(path, oc, nc) => git_diff_text(oc, nc, path, path, 3)
    Added(path, nc) => {
      let sha = git_blob_hash(nc)
      "diff --git a/" + path + " b/" + path + "\n" +
      "new file mode 100644\n" +
      "index 0000000000000000000000000000000000000000.." + sha + "\n" +
      to_unified(diff_lines("", nc), "/dev/null", "b/" + path, 3)
    }
    Removed(path, oc) => {
      let sha = git_blob_hash(oc)
      "diff --git a/" + path + " b/" + path + "\n" +
      "deleted file mode 100644\n" +
      "index " + sha + "..0000000000000000000000000000000000000000\n" +
      to_unified(diff_lines(oc, ""), "a/" + path, "/dev/null", 3)
    }
    Renamed(from, to) => {
      let oc = match fileset_get(old_fs, from) {
        Some(x) => x
        None => ""
      }
      let nc = match fileset_get(new_fs, to) {
        Some(x) => x
        None => ""
      }
      let sim = similarity(oc, nc)
      let head =
        "diff --git a/" + from + " b/" + to + "\n" +
        "similarity index " + sim.to_string() + "%\n" +
        "rename from " + from + "\n" +
        "rename to " + to + "\n"
      if oc == nc {
        head
      } else {
        head + to_unified(diff_lines(oc, nc), "a/" + from, "b/" + to, 3)
      }
    }
  }
}

/// The primary path of a change (used for sorting output deterministically).
fn change_sort_key(c: FileChange) -> String {
  match c {
    Added(p, _) => p
    Removed(p, _) => p
    Modified(p, _, _) => p
    Renamed(_, to) => to
  }
}

/// Renders a full multi-file Git patch for the diff between two trees.
pub fn render_tree_patch(
  old_fs: Array[(String, String)],
  new_fs: Array[(String, String)],
  threshold: Int
) -> String {
  let td = diff_trees(old_fs, new_fs, threshold)
  // stable sort of changes by primary path
  let cs = td.changes
  for i = 1; i < cs.length(); i = i + 1 {
    let mut j = i
    while j > 0 && change_sort_key(cs[j - 1]) > change_sort_key(cs[j]) {
      let tmp = cs[j - 1]
      cs[j - 1] = cs[j]
      cs[j] = tmp
      j = j - 1
    }
  }
  let parts: Array[String] = []
  for c in cs {
    parts.push(render_change(c, old_fs, new_fs))
  }
  parts.join("")
}

/// A short human-readable summary of a tree diff, e.g.
/// `2 files changed, 1 renamed, 3 insertions(+), 1 deletion(-)`.
pub fn tree_diff_summary(td: TreeDiff) -> String {
  let mut added = 0
  let mut removed = 0
  let mut modified = 0
  let mut renamed = 0
  let mut ins = 0
  let mut del = 0
  for c in td.changes {
    match c {
      Added(_, _) => added = added + 1
      Removed(_, _) => removed = removed + 1
      Modified(_, oc, nc) => {
        modified = modified + 1
        let d = diff_lines(oc, nc)
        for ch in d {
          match ch {
            Insert(_) => ins = ins + 1
            Delete(_) => del = del + 1
            Equal(_) => ()
          }
        }
      }
      Renamed(_, _) => renamed = renamed + 1
    }
  }
  let mut s = (added + removed + modified + renamed).to_string() + " files changed"
  if renamed > 0 {
    s = s + ", " + renamed.to_string() + " renamed"
  }
  if ins > 0 {
    s = s + ", " + ins.to_string() + " insertions(+)"
  }
  if del > 0 {
    s = s + ", " + del.to_string() + " deletions(-)"
  }
  s
}

/// Builds the new-file content from a Git hunk by keeping `+` (added) and
/// ` ` (context) lines. This avoids the trailing-empty-line artifact that
/// `apply_unified` would introduce when the old side is `/dev/null`.
fn content_from_add_hunk(hunk: Array[String]) -> String {
  let lines: Array[String] = []
  for line in hunk {
    if line.length() >= 1 {
      let fc = line[0].to_int()
      if fc == '+'.to_int() || fc == ' '.to_int() {
        lines.push(line[1:].to_owned())
      }
    }
  }
  lines.join("\n")
}

/// Applies a multi-file Git patch (as produced by `render_tree_patch`) to a
/// file tree, returning the resulting tree or an error message.
pub fn apply_tree_patch(
  old_fs: Array[(String, String)],
  patch: String
) -> Result[Array[(String, String)], String] {
  let work = fileset(old_fs)
  let lines = split_lines(patch)
  // group into per-file sections separated by "diff --git"
  let sections: Array[Array[String]] = []
  let mut cur: Array[String] = []
  for line in lines {
    if line.length() >= 11 && substring(line, 0, 11) == "diff --git " {
      if cur.length() > 0 {
        sections.push(cur)
        cur = []
      }
      cur.push(line)
    } else if line.length() > 0 || cur.length() > 0 {
      cur.push(line)
    }
  }
  if cur.length() > 0 {
    sections.push(cur)
  }
  for sec in sections {
    if sec.length() == 0 {
      continue
    }
    let mut rename_from = ""
    let mut rename_to = ""
    let mut old_name = ""
    let mut new_name = ""
    let mut is_new = false
    let mut is_del = false
    let mut first_at = -1
    for si = 0; si < sec.length(); si = si + 1 {
      let l = sec[si]
      if substring(l, 0, 12) == "rename from " {
        rename_from = substring(l, 12, l.length())
      } else if substring(l, 0, 10) == "rename to " {
        rename_to = substring(l, 10, l.length())
      } else if substring(l, 0, 9) == "new file " {
        is_new = true
      } else if substring(l, 0, 13) == "deleted file " {
        is_del = true
      } else if substring(l, 0, 4) == "--- " {
        old_name = strip_dir(substring(l, 4, l.length()))
      } else if substring(l, 0, 4) == "+++ " {
        new_name = strip_dir(substring(l, 4, l.length()))
      } else if substring(l, 0, 2) == "@@" {
        first_at = si
      }
    }
    if first_at < 0 && rename_from.length() == 0 {
      continue
    }
    let hunk: Array[String] = []
    if first_at >= 0 {
      for si = first_at; si < sec.length(); si = si + 1 {
        hunk.push(sec[si])
      }
    }
    if rename_from.length() > 0 {
      // remove the source, add (or move to) the destination
      let oc = match fileset_get(work, rename_from) {
        Some(x) => x
        None => ""
      }
      let nc =
        if hunk.length() > 0 {
          apply_unified(oc, hunk_lines_to_text(hunk))
        } else {
          oc
        }
      // remove source
      let mut k = 0
      while k < work.length() {
        if work[k].0 == rename_from {
          let _ = work.remove(k)
        } else {
          k = k + 1
        }
      }
      work.push((rename_to, nc))
    } else if is_new {
      let content = content_from_add_hunk(hunk)
      work.push((new_name, content))
    } else if is_del {
      let mut k = 0
      while k < work.length() {
        if work[k].0 == old_name {
          let _ = work.remove(k)
        } else {
          k = k + 1
        }
      }
    } else {
      // modified
      let oc = match fileset_get(work, old_name) {
        Some(x) => x
        None => ""
      }
      let nc = apply_unified(oc, hunk_lines_to_text(hunk))
      // replace existing entry or add
      let mut replaced = false
      for ki = 0; ki < work.length(); ki = ki + 1 {
        if work[ki].0 == new_name {
          work[ki] = (new_name, nc)
          replaced = true
        }
      }
      if !replaced {
        work.push((new_name, nc))
      }
    }
  }
  Ok(fileset(work))
}

/// Joins hunk lines back into patch text for `apply_unified`.
fn hunk_lines_to_text(hunk: Array[String]) -> String {
  hunk.join("\n")
}
