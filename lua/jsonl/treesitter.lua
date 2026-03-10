local M = {}

M.setup = function()
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok then
		vim.notify("ndjson.nvim: nvim-treesitter not found, highlighting unavailable", vim.log.levels.WARN)
		return
	end

	parsers.get_parser_configs().jsonl = {
		install_info = {
			url = "https://codeberg.org/kristoferssolo/tree-sitter-jsonl",
			files = { "src/parser.c" },
			branch = "main",
		},
		filetype = "jsonl",
	}
end

return M
