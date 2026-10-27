local M = {}

local install_info = {
	url = "https://github.com/kristoferssolo/tree-sitter-jsonl",
	branch = "main",
}

-- Install info re-registered on `User TSUpdate`, including user overrides.
local active_install_info = vim.deepcopy(install_info)

local function is_master_branch(parsers)
	return type(parsers.get_parser_configs) == "function"
end

-- nvim-treesitter master branch: parser configs live behind get_parser_configs().
local function setup_legacy(parsers, opts)
	local parser_configs = parsers.get_parser_configs()
	parser_configs.jsonl = parser_configs.jsonl
		or {
			install_info = vim.tbl_extend("force", install_info, { files = { "src/parser.c" } }),
			filetype = "jsonl",
		}

	if opts ~= nil then
		parser_configs.jsonl = vim.tbl_deep_extend("force", parser_configs.jsonl, opts)
	end
end

-- nvim-treesitter main branch: the module itself is the parser config table.
local function setup_main(parsers, opts)
	local parser_config = parsers.jsonl or { install_info = vim.deepcopy(install_info) }

	if opts ~= nil then
		parser_config = vim.tbl_deep_extend("force", parser_config, opts)
	end

	parsers.jsonl = parser_config
	active_install_info = vim.deepcopy(parser_config.install_info or install_info)

	-- Installing or updating parsers reloads the parser table and fires
	-- `User TSUpdate`. Re-register jsonl so it survives that reload.
	vim.api.nvim_create_autocmd("User", {
		group = vim.api.nvim_create_augroup("jsonl.nvim", { clear = true }),
		pattern = "TSUpdate",
		callback = function()
			local ok, reloaded = pcall(require, "nvim-treesitter.parsers")
			if not ok or is_master_branch(reloaded) or reloaded.jsonl ~= nil then
				return
			end
			reloaded.jsonl = { install_info = vim.deepcopy(active_install_info) }
		end,
	})
end

M.setup = function(opts)
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if not ok then
		return
	end

	if is_master_branch(parsers) then
		setup_legacy(parsers, opts)
	else
		setup_main(parsers, opts)
	end
end

return M
