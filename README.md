# jsonl.nvim

JSONL / NDJSON filetype support for Neovim with Tree-sitter injection queries.

## lazy.nvim

```lua
{
  "https://codeberg.org/kristoferssolo/jsonl.nvim",
   dependencies = { "nvim-treesitter/nvim-treesitter" },
  ft = { "ndjson", "jsonl", "jsonlines" },
  opts = {},
}
```

## License

Licensed under [MIT license](LICENSE-MIT).
