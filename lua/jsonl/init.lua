local M = {}
local defaults = {}

M._options = vim.deepcopy(defaults)
M._activated = false

M.setup = function(opts)
	M._options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

M.activate = function()
	if M._activated then
		return
	end

	M._activated = true
	require("jsonl.treesitter").setup(M._options)
end

return M
