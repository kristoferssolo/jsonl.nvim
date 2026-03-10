local M = {}
local configured = false

M.setup = function()
	if configured then
		return
	end

	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok then
		return
	end

	local parser_configs = parsers.get_parser_configs()
	if parser_configs.jsonl ~= nil then
		configured = true
		return
	end

	parser_configs.jsonl = {
		install_info = {
			url = "https://codeberg.org/kristoferssolo/tree-sitter-jsonl",
			files = { "src/parser.c" },
			branch = "main",
		},
		filetype = "jsonl",
	}

	configured = true
end

return M
