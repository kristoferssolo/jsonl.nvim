require("jsonl.treesitter").setup()

vim.api.nvim_create_user_command("JSONLConvert", function()
	require("jsonl.convert").toggle()
end, { desc = "Convert between JSONL and a JSON array" })
