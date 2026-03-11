local M = {}

M.setup = function(opts)
	require("jsonl.treesitter").setup((opts and opts.treesitter) or opts or nil)
end

return M
