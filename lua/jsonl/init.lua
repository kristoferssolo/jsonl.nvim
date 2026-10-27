local M = {}

M.setup = function(opts)
	opts = opts or {}

	require("jsonl.convert").json_formatter = opts.json_formatter

	-- Keep supporting flat treesitter options for existing configs.
	local treesitter = opts.treesitter
	if treesitter == nil then
		treesitter = vim.deepcopy(opts)
		treesitter.treesitter = nil
		treesitter.json_formatter = nil
	end

	require("jsonl.treesitter").setup(treesitter)
end

return M
