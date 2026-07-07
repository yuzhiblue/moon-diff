// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.

/// Escapes the three HTML-significant characters (`&`, `<`, `>`) so a raw text
/// line can be embedded safely inside an HTML document.
fn escape_html(s: String) -> String {
  let mut out: String = ""
  for i = 0; i < s.length(); i = i + 1 {
    let c = code_at(s, i).unsafe_to_char()
    if c == '<' {
      out = out + "&lt;"
    } else if c == '>' {
      out = out + "&gt;"
    } else if c == '&' {
      out = out + "&amp;"
    } else {
      out = out + String::from_array([c])
    }
  }
  out
}

/// Renders a line-level unified diff of `old`/`new` as a self-contained HTML
/// `<table>` fragment (no surrounding `<html>`/`<style>`). Added lines get the
/// `ins` class, removed lines `del`, hunk headers `hunk`, and context lines
/// `ctx` — so a small stylesheet can colour them like a typical code-review UI.
pub fn unified_to_html(
  old: String,
  new: String,
  context: Int
) -> String {
  let patch = to_unified(diff_lines(old, new), "old", "new", context)
  let lines = split_lines(patch)
  let rows: Array[String] = []
  for line in lines {
    if line.length() == 0 {
      rows.push("<tr class=\"ctx\"><td>&nbsp;</td></tr>\n")
    } else {
      let fc = line[0].to_int()
      if fc == '+'.to_int() {
        rows.push(
          "<tr class=\"ins\"><td>" + escape_html(line[1:].to_owned()) +
          "</td></tr>\n",
        )
      } else if fc == '-'.to_int() {
        rows.push(
          "<tr class=\"del\"><td>" + escape_html(line[1:].to_owned()) +
          "</td></tr>\n",
        )
      } else if fc == '@'.to_int() {
        rows.push("<tr class=\"hunk\"><td>" + escape_html(line) + "</td></tr>\n")
      } else {
        rows.push(
          "<tr class=\"ctx\"><td>" + escape_html(line[1:].to_owned()) +
          "</td></tr>\n",
        )
      }
    }
  }
  "<table class=\"diff\">\n" + rows.join("") + "</table>\n"
}

/// Renders a whole HTML page (with a minimal inline stylesheet) for the diff
/// between `old` and `new`. Handy for quick visual inspection / reports.
pub fn diff_html_page(
  old: String,
  new: String,
  context: Int,
  title: String
) -> String {
  let body = unified_to_html(old, new, context)
  let style =
    "table.diff{font-family:monospace;border-collapse:collapse}" +
    "table.diff td{padding:0 8px;border:1px solid #eee}" +
    "tr.ins{background:#e6ffed}tr.del{background:#ffeef0}" +
    "tr.hunk{background:#f6f8fa;color:#666}"
  "<html><head><meta charset=\"utf-8\"><title>" + escape_html(title) +
  "</title><style>" + style + "</style></head><body>\n" + body +
  "</body></html>\n"
}
