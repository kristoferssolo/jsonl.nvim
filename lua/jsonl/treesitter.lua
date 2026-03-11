local M = {}
local default_config = {
	install_info = {
		url = "https://codeberg.org/kristoferssolo/tree-sitter-jsonl",
		files = { "src/parser.c" },
		branch = "main",
	},
	filetype = "jsonl",
}
M.defaults = vim.deepcopy(default_config)
M._configured = false

M.setup = function()
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok then
		return
	end

	local parser_configs = parsers.get_parser_configs()
	if parser_configs.jsonl == nil then
		parser_configs.jsonl = vim.deepcopy(default_config)
	end

	if opts ~= nil then
		parser_configs.jsonl = vim.tbl_deep_extend("force", parser_configs.jsonl, opts)
	end

	M._configured = true
end

return M
