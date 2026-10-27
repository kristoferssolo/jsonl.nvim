# jsonl.nvim

JSONL / NDJSON filetype support for Neovim with Tree-sitter injection queries.

## lazy.nvim

```lua
return {
	"kristoferssolo/jsonl.nvim",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	init = function()
		vim.filetype.add({
			extension = {
				jsonl = "jsonl",
				jsonlines = "jsonl",
				ndjson = "jsonl",
			},
		})
	end,
	ft = { "jsonl", "json" },
	keys = {
		{
			"<leader>jc",
			"<cmd>JSONLConvert<cr>",
			ft = { "jsonl", "json" },
			desc = "Convert between JSONL and JSON",
		},
	},
	opts = {
		-- json_formatter = function(bufnr)
		-- 	-- conform
		-- 	require("conform").format({ bufnr = bufnr, async = false })
		-- end,
	},
}
```

## Tree-sitter parser

Install the parser once:

```
:TSInstall jsonl
```

Or add `"jsonl"` to `ensure_installed` in your `nvim-treesitter` setup.

## Converting between JSONL and JSON

The plugin adds the `:JSONLConvert` command:

- In a JSONL buffer, it writes a sibling `.json` file containing a JSON array of
  all records.
- In a `.json` buffer containing an array, it writes a sibling `.jsonl` file
  with one JSON value per line. JSONL output is never reformatted.

The buffer must be saved first. The converted file is opened after it is
written. No formatter runs by default; see [Formatting](#formatting) to opt in.

### Formatting

Conversion never invokes a formatter, so it behaves the same whether you use
Conform, prettierd, or nothing at all. Opt in with `json_formatter`: it receives
the buffer holding the written JSON array and the target path. Modify the buffer
and the plugin writes it back; leave it untouched and the file keeps the
unformatted output. A formatter error is reported without aborting the
conversion.

With Conform, formatting matches your `formatters_by_ft` and project config.
`async = false` is required, since the file is written back right after the hook
returns:

```lua
opts = {
	json_formatter = function(bufnr)
		require("conform").format({ bufnr = bufnr, async = false })
	end,
},
```

Or with `prettierd` directly:

```lua
opts = {
	json_formatter = function(bufnr, path)
		local prettierd = vim.fn.exepath("prettierd")
		if prettierd == "" then
			return
		end
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local stdin = table.concat(lines, "\n")
		local result = vim.system({ prettierd, path }, { stdin = stdin, text = true }):wait()
		if result.code ~= 0 then
			return
		end
		local formatted = vim.split(vim.trim(result.stdout), "\n", { plain = true })
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted)
	end,
},
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

This project is licensed under the MIT License – see the [LICENSE](LICENSE) file for details.
