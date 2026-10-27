local M = {}

--- Optional hook that formats the generated JSON. It runs after the array is
--- written and opened, and receives the target buffer and path. Modify the
--- buffer (for example with Conform); the plugin writes it back if it is left
--- modified. Leaving it unset writes the array without formatting.
---@type nil|fun(bufnr: integer, path: string)
M.json_formatter = nil

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "jsonl.nvim" })
end

-- Split a JSON array body at its top-level commas, ignoring commas inside
-- strings and nested arrays/objects.
local function split_top_level(s)
	local parts = {}
	local depth = 0
	local in_string = false
	local escaped = false
	local start = 1

	for i = 1, #s do
		local char = s:sub(i, i)
		if in_string then
			if escaped then
				escaped = false
			elseif char == "\\" then
				escaped = true
			elseif char == '"' then
				in_string = false
			end
		elseif char == '"' then
			in_string = true
		elseif char == "{" or char == "[" then
			depth = depth + 1
		elseif char == "}" or char == "]" then
			depth = depth - 1
		elseif char == "," and depth == 0 then
			parts[#parts + 1] = s:sub(start, i - 1)
			start = i + 1
		end
	end

	parts[#parts + 1] = s:sub(start)
	return parts
end

-- Collapse prettier's line wrapping back to a single line, preserving
-- whitespace inside strings.
local function collapse_whitespace(s)
	local out = {}
	local in_string = false
	local escaped = false
	local pending_space = false

	for i = 1, #s do
		local char = s:sub(i, i)
		if in_string then
			out[#out + 1] = char
			if escaped then
				escaped = false
			elseif char == "\\" then
				escaped = true
			elseif char == '"' then
				in_string = false
			end
		elseif char == '"' then
			if pending_space and #out > 0 and out[#out] ~= "[" then
				out[#out + 1] = " "
			end
			pending_space = false
			in_string = true
			out[#out + 1] = char
		elseif char:match("%s") then
			pending_space = true
		else
			if pending_space and #out > 0 then
				local prev = out[#out]
				if prev ~= "[" and not (char == "]" or (char == "}" and prev == "{")) then
					out[#out + 1] = " "
				end
			end
			pending_space = false
			out[#out + 1] = char
		end
	end

	return table.concat(out)
end

-- Return the conversion target for the current buffer, or nil after notifying
-- why the conversion cannot run.
local function resolve_target(ext)
	local src = vim.api.nvim_buf_get_name(0)
	if src == "" then
		notify("Buffer has no file name", vim.log.levels.WARN)
		return nil
	end
	if vim.bo.modified then
		notify("Save the buffer before converting", vim.log.levels.WARN)
		return nil
	end

	local target = vim.fn.fnamemodify(src, ":r") .. ext
	if target == src then
		notify("Source and target are the same file", vim.log.levels.WARN)
		return nil
	end
	return target
end

-- Write and open the target, refusing to clobber a buffer with unsaved changes.
local function write_target(path, lines)
	local bufnr = vim.fn.bufnr(path)
	if bufnr ~= -1 and vim.bo[bufnr].modified then
		notify("Target buffer has unsaved changes: " .. path, vim.log.levels.WARN)
		return false
	end

	vim.fn.writefile(lines, path)
	notify("Wrote " .. path)
	vim.cmd("edit! " .. vim.fn.fnameescape(path))
	return true
end

-- Run the user-provided formatter on the written buffer. A failing formatter
-- leaves the unformatted file in place so it never blocks the conversion.
local function apply_json_formatter(bufnr, path)
	if type(M.json_formatter) ~= "function" then
		return
	end

	local ok, err = pcall(M.json_formatter, bufnr, path)
	if not ok then
		notify("json_formatter failed: " .. tostring(err), vim.log.levels.WARN)
		return
	end

	if not vim.api.nvim_buf_is_loaded(bufnr) or not vim.bo[bufnr].modified then
		return
	end

	local wrote, write_err = pcall(vim.api.nvim_buf_call, bufnr, function()
		vim.cmd("silent write")
	end)
	if not wrote then
		notify("Failed to write formatted JSON: " .. tostring(write_err), vim.log.levels.WARN)
	end
end

--- Convert the current JSONL buffer to a JSON array file.
function M.to_json()
	local target = resolve_target(".json")
	if not target then
		return
	end

	local records = {}
	for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		if line:match("%S") then
			local ok, err = pcall(vim.json.decode, line)
			if not ok then
				notify(("Invalid JSON on line %d: %s"):format(i, err), vim.log.levels.ERROR)
				return
			end
			records[#records + 1] = line
		end
	end

	local raw = #records == 0 and "[]" or ("[\n" .. table.concat(records, ",\n") .. "\n]")
	if write_target(target, vim.split(raw, "\n", { plain = true })) then
		apply_json_formatter(vim.api.nvim_get_current_buf(), target)
	end
end

--- Convert the current JSON array buffer to a JSONL file.
function M.to_jsonl()
	local target = resolve_target(".jsonl")
	if not target then
		return
	end

	local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"))
	if text == "" then
		notify("Buffer is empty", vim.log.levels.WARN)
		return
	end
	if text:sub(1, 1) ~= "[" or text:sub(-1) ~= "]" then
		notify("Current buffer is not a JSON array", vim.log.levels.ERROR)
		return
	end

	local ok, err = pcall(vim.json.decode, text)
	if not ok then
		notify("Invalid JSON: " .. tostring(err), vim.log.levels.ERROR)
		return
	end

	local out = {}
	for _, element in ipairs(split_top_level(text:sub(2, -2))) do
		element = vim.trim(element)
		if element ~= "" then
			out[#out + 1] = collapse_whitespace(element)
		end
	end

	write_target(target, out)
end

--- Convert based on the current filetype.
function M.toggle()
	local ft = vim.bo.filetype
	if ft == "jsonl" then
		M.to_json()
	elseif ft == "json" then
		M.to_jsonl()
	else
		notify("Not a JSONL or JSON buffer", vim.log.levels.WARN)
	end
end

return M
