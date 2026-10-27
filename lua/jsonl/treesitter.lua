local M = {}
local default_install_info = {
	url = "https://github.com/kristoferssolo/tree-sitter-jsonl",
	files = { "src/parser.c" },
	branch = "main",
}
local default_config = {
	install_info = default_install_info,
	filetype = "jsonl",
}
local main_install_info = {
	url = "https://github.com/kristoferssolo/tree-sitter-jsonl",
	branch = "main",
}
M.defaults = vim.deepcopy(default_config)
M._configured = false
M._install_info = vim.deepcopy(main_install_info)

local function is_legacy(parsers)
	return type(parsers.get_parser_configs) == "function"
end

-- nvim-treesitter master branch: parser configs live behind get_parser_configs().
local function setup_legacy(parsers, opts)
	local parser_configs = parsers.get_parser_configs()
	if parser_configs.jsonl == nil then
		parser_configs.jsonl = vim.deepcopy(default_config)
	end

	if opts ~= nil then
		parser_configs.jsonl = vim.tbl_deep_extend("force", parser_configs.jsonl, opts)
	end
end

-- nvim-treesitter main branch: the module itself is the parser config table.
local function setup_main(parsers, opts)
	local parser_config = parsers.jsonl
	if parser_config == nil then
		parser_config = { install_info = vim.deepcopy(main_install_info) }
	end

	if opts ~= nil then
		parser_config = vim.tbl_deep_extend("force", parser_config, opts)
	end

	parsers.jsonl = parser_config
	M._install_info = vim.deepcopy(parser_config.install_info or main_install_info)
end

-- On the main branch, installing or updating parsers reloads the parser table
-- and fires `User TSUpdate`. Re-register jsonl so it survives that reload.
local function create_autocmd()
	if M._autocmd_created then
		return
	end
	M._autocmd_created = true

	vim.api.nvim_create_autocmd("User", {
		group = vim.api.nvim_create_augroup("jsonl.nvim", { clear = true }),
		pattern = "TSUpdate",
		callback = function()
			local ok, parsers = pcall(require, "nvim-treesitter.parsers")
			if not ok or is_legacy(parsers) or parsers.jsonl ~= nil then
				return
			end
			parsers.jsonl = { install_info = vim.deepcopy(M._install_info) }
		end,
	})
end

M.setup = function(opts)
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok then
		return
	end

	if is_legacy(parsers) then
		setup_legacy(parsers, opts)
	else
		setup_main(parsers, opts)
		create_autocmd()
	end

	M._configured = true
end

return M
