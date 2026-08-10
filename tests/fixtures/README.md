# Test fixtures

These files are saved HTML used by `tests/run-offline.ps1`. Nothing here is
fetched at test time; the suite never sends a live query.

## Why captured pages are here

Hand-written fixtures only contain the markup someone already thought to write.
They kept passing while the parser failed on ordinary pages, because the shapes
that broke it were shapes nobody had written down. These fixtures start from a
real response so the layout, nesting depth, whitespace, and attribute style are
the provider's rather than mine.

## Files

| File | Purpose |
| --- | --- |
| `duckduckgo-html-results.html` | A captured results page. Exercises protocol-relative redirect links, entity-encoded attributes, and inline `<b>` highlighting inside snippets. |
| `duckduckgo-html-results-noscript.html` | The same page with a `<noscript>`-wrapped `<iframe>` and a `<noscript><style>` block added, matching the hidden-element nesting that ordinary pages carry. |

## Sanitization

Captured markup is never committed as received. Before a capture becomes a
fixture:

- per-request tokens are zeroed, including the `vqd` form value and every `rut`
  parameter;
- every third-party target URL is replaced with an `example.com` placeholder,
  keeping the original percent-encoding so redirect unwrapping is still tested;
- result titles, snippet text, and displayed URLs are replaced with placeholder
  wording that preserves the surrounding markup, including highlight tags;
- favicon hosts are pointed at a placeholder domain.

The structure is real. The words are not. This keeps result content and
third-party material out of the repository, which
[PROVIDER-NOTICE.md](../../PROVIDER-NOTICE.md) requires, while leaving the
fixture useful as a parser test.

## Refreshing or adding a capture

Capturing a page is a manual, deliberate step. Take a single request, never a
loop, and use a query with no personal meaning. Sanitize it as above, confirm no
token or third-party string survives, and check the expected values in
`tests/run-offline.ps1` still describe the fixture.
