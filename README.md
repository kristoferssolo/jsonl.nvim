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

## conform.nvim

If you use [Conform](https://github.com/stevearc/conform.nvim)'s `injected` formatter, it may also try to format `jsonl`
buffers through the JSON injection query. You can disable that by skipping the
formatter for JSONL-style filenames:

```lua
require("conform").setup({
	formatters = {
		injected = {
			condition = function(_, ctx)
				return not ctx.filename:match("%.jsonl$")
					and not ctx.filename:match("%.ndjson$")
					and not ctx.filename:match("%.jsonlines$")
			end,
		},
	},
})
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
