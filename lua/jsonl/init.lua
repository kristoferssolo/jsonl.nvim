local M = {}

M.setup = function(opts)
	require("jsonl.treesitter").setup(opts or opts.treesitter or nil)
end

return M
