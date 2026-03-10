# jsonl.nvim

JSONL / NDJSON filetype support for Neovim with Tree-sitter injection queries.

## lazy.nvim

For custom file extensions, load the plugin on matching buffer events instead
of `ft = "jsonl"`, otherwise Neovim will not know the `jsonl` filetype early
enough to trigger filetype-based lazy loading.

```lua
{
  "kristoferssolo/jsonl.nvim",
  event = {
    "BufReadPre *.jsonl",
    "BufNewFile *.jsonl",
    "BufReadPre *.jsonlines",
    "BufNewFile *.jsonlines",
    "BufReadPre *.ndjson",
    "BufNewFile *.ndjson",
  },
  opts = {},
}
```
