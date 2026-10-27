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

local QUOTE, BACKSLASH, COMMA = 34, 92, 44
local LBRACKET, RBRACKET, LBRACE, RBRACE = 91, 93, 123, 125

local function is_space(b)
	return b == 32 or (b >= 9 and b <= 13)
end

-- Split a validated JSON array body into its top-level elements, each collapsed
-- onto one line. Whitespace inside strings is kept. Elsewhere a whitespace run
-- becomes one space, except after `[`, before `]`, and between `{` and `}`.
-- Scans bytes so LuaJIT can compile the loop, and copies whole runs between
-- whitespace with one `sub`.
local function split_elements(body)
	local elements = {}
	local out = {}
	local depth = 0
	local in_string, escaped, pending_space = false, false, false
	local run_start = nil
	local last = nil

	local function flush_run(run_end)
		if run_start ~= nil then
			out[#out + 1] = body:sub(run_start, run_end)
			last = body:byte(run_end)
			run_start = nil
		end
	end

	local function finish_element()
		if #out > 0 then
			elements[#elements + 1] = table.concat(out)
		end
		out, last, pending_space = {}, nil, false
	end

	for i = 1, #body do
		local b = body:byte(i)
		if in_string then
			if escaped then
				escaped = false
			elseif b == BACKSLASH then
				escaped = true
			elseif b == QUOTE then
				in_string = false
			end
		elseif is_space(b) then
			flush_run(i - 1)
			pending_space = true
		elseif b == COMMA and depth == 0 then
			flush_run(i - 1)
			finish_element()
		else
			if run_start == nil then
				if
					pending_space
					and last ~= nil
					and last ~= LBRACKET
					and b ~= RBRACKET
					and not (b == RBRACE and last == LBRACE)
				then
					out[#out + 1] = " "
				end
				pending_space = false
				run_start = i
			end

			if b == QUOTE then
				in_string = true
			elseif b == LBRACE or b == LBRACKET then
				depth = depth + 1
			elseif b == RBRACE or b == RBRACKET then
				depth = depth - 1
			end
		end
	end

	flush_run(#body)
	finish_element()
	return elements
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

	write_target(target, split_elements(text:sub(2, -2)))
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
