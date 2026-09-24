# Integration spikes

- IRB 1.18's `IRB::Inspector` supports a streaming inspector that writes into IRB's result buffer. Inlay writes terminal escapes to `$stdout` separately and leaves a short summary in the buffer. IRB paging and assignment truncation therefore only see the summary. The supported minimum is IRB 1.13, the first version with the supported inspector API.
- `.irbrc` runs before the first prompt, so environment-based terminal detection can be cached at install time without competing with Reline input. Inlay does not issue device queries.
- Rails console uses IRB's configured inspector when initialized after `.irbrc`; re-running `Inlay.irb_install!` wraps a subsequently selected inspector. Rails itself is not part of the test dependency set.
- Pry's configured printer receives `(output, value, pry_instance)`; the adapter retains that printer and passes it the summary.
- IRuby's public display registry supports predicate matchers and dynamic MIME pairs. SVG is preferred; PNG and GIF-in-HTML are selected from the normalized return value.
- `@ruby/3.4-wasm-wasi` 2.10.1 / Ruby 3.4.1 with Larb and JS host bindings completed 3,600 simulated 60 fps callbacks in 61.95 seconds. With one stable JS trampoline and Ruby/JS GC every 600 frames, WASM memory changed from 71,499,776 to 71,565,312 bytes; JS heap grew 4,261,280 bytes. This validates the callback strategy under Node, not a browser or GPU workload.
