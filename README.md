# jsonl.nvim

JSONL / NDJSON support for Neovim.

- Detects `.jsonl`, `.jsonlines`, and `.ndjson` files as the `jsonl` filetype.
- Highlights each line as JSON through a Tree-sitter injection.
- Converts between JSONL and JSON arrays with `:JSONLConvert`.

## Installation

Requires [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter),
either the `master` or `main` branch.

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
	"kristoferssolo/jsonl.nvim",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	-- Filetype detection has to run before `ft` can trigger the lazy load.
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
	opts = {},
}
```

Then install the parsers. Highlighting needs both `jsonl` and `json`:

```vim
:TSInstall jsonl json
```

## Converting

`:JSONLConvert` writes a sibling file with the other extension and opens it.

| Buffer       | Writes       | Output                     |
| ------------ | ------------ | -------------------------- |
| `data.jsonl` | `data.json`  | JSON array of all records  |
| `data.json`  | `data.jsonl` | One array element per line |

- Save the buffer first. The command refuses to convert unsaved changes.
- An existing target file is overwritten, unless it is open with unsaved changes.
- Every record is validated. Blank JSONL lines are skipped.
- JSON to JSONL keeps each element's original text, including key order and
  number formatting. Multi-line elements are joined onto one line.

## Configuration

```lua
opts = {
	-- Format the generated JSON array. See below.
	json_formatter = nil,
	-- Merged into the jsonl parser config passed to nvim-treesitter.
	treesitter = nil,
}
```

### Formatting JSON output

By default the JSON array is written as-is, one record per line. Set
`json_formatter` to format it. The function receives the buffer holding the
new file and its path. Edit the buffer and the plugin saves it. If the
formatter throws, the plugin reports the error and keeps the unformatted file.
JSONL output is never formatted.

With [conform.nvim](https://github.com/stevearc/conform.nvim), using your
`formatters_by_ft` and project config. `async = false` is required because the
plugin saves the buffer right after the function returns:

```lua
opts = {
	json_formatter = function(bufnr)
		require("conform").format({ bufnr = bufnr, async = false })
	end,
}
```

With `prettierd` directly:

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
}
```

With `jq`. Change `--indent` to set the width, or use `--tab`. jq before 1.7
rewrites large integers as floats.

```lua
opts = {
	json_formatter = function(bufnr)
		local jq = vim.fn.exepath("jq")
		if jq == "" then
			return
		end
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local stdin = table.concat(lines, "\n")
		local result = vim.system({ jq, "--indent", "2", "." }, { stdin = stdin, text = true }):wait()
		if result.code ~= 0 then
			return
		end
		local formatted = vim.split(vim.trim(result.stdout), "\n", { plain = true })
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted)
	end,
}
```

## Conform's `injected` formatter

Conform's `injected` formatter follows the JSON injection and can reformat
JSONL buffers, spreading records across multiple lines. Skip it for JSONL
files:

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

MIT. See [LICENSE](LICENSE).
