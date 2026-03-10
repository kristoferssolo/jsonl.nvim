local M = {}

M.setup = function(opts)
	opts = opts or {}
	require("jsonl.treesitter").setup()
end

return M
