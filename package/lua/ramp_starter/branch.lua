local M = {}
local configured = false
local api = ramp.api

local PENDING_MS = 30000
local TOOL_OUTPUT_LINES = 20

local current, previous
local pending, ready

local function first_line(text, width)
    local line = (text or ''):match('^%s*([^\n]*)') or ''
    if utf8.len(line) and utf8.len(line) > width then
        line = line:sub(1, utf8.offset(line, width) - 1) .. '…'
    end
    return line
end

local function head(text, lines)
    local kept, count = {}, 0
    for line in ((text or '') .. '\n'):gmatch('([^\n]*)\n') do
        count = count + 1
        if count <= lines then kept[#kept + 1] = line end
    end
    if count > lines then kept[#kept + 1] = ('… %d more lines'):format(count - lines) end
    return table.concat(kept, '\n')
end

local function quote(text)
    return '> ' .. text:gsub('\n', '\n> ')
end

local function entries(from, to)
    local found = {}
    while from <= to do
        local page = api.transcript_entries({ from = from, limit = math.min(200, to - from + 1) })
        if #page.entries == 0 then break end
        for _, entry in ipairs(page.entries) do found[#found + 1] = entry end
        from = from + #page.entries
    end
    return found
end

local function latest_reply()
    local page = api.transcript_entries({ from = -50, limit = 50 })
    for i = #page.entries, 1, -1 do
        if page.entries[i].kind == 'assistant' then return page.entries[i] end
    end
end

function M.targets()
    local found = {}
    if api.get_state().mode == 't' then
        for _, entry in ipairs(api.get_selected_entries()) do
            if entry.kind ~= 'note' then found[#found + 1] = entry end
        end
    end
    if #found == 0 then found[1] = latest_reply() end
    return found
end

function M.label(entry)
    if entry.kind == 'tool' then
        return entry.name .. ' ' .. first_line(entry.input_text or entry.input, 30)
    end
    return first_line(entry.text, 40)
end

local function excerpt(entry)
    if entry.kind == 'tool' then
        return ('The `%s` call (%s) returned:\n```\n%s\n```'):format(
            entry.name, first_line(entry.input_text or entry.input, 120),
            head(entry.output or entry.text, TOOL_OUTPUT_LINES))
    elseif entry.kind == 'user' then
        return 'I asked:\n' .. quote(entry.text)
    end
    return quote(entry.text)
end

function M.excerpts(list)
    local parts = {}
    for _, entry in ipairs(list) do parts[#parts + 1] = excerpt(entry) end
    return table.concat(parts, '\n\n')
end

function M.this_session()
    local target = api.get_state().session_target
    for _, session in ipairs(api.get_sessions()) do
        if session.target == target then return session end
    end
end

local function expect_attach(after)
    after.deadline = api.get_state().elapsed_ms + PENDING_MS
    pending = after
end

function M.branch_here()
    local state = api.get_state()
    local index = state.mode == 't' and state.entry_cursor or (latest_reply() or {}).index
    local entry = index and api.transcript_entries({ from = index, limit = 1 }).entries[1]
    if not entry then
        ramp.notify('Nothing to branch from yet', 'warn')
        return
    end
    if entry.kind ~= 'user' and entry.kind ~= 'assistant' and entry.kind ~= 'tool' then
        ramp.notify('Select a prompt, completed call, or reply to branch here', 'warn')
        return
    end
    expect_attach({ draft = entry.kind == 'user' and entry.text or nil })
    local ok, err = pcall(api.fork_at, entry, 'Branch: ' .. M.label(entry))
    if not ok then
        pending = nil
        ramp.notify('Could not branch: ' .. tostring(err), 'error')
    end
end

function M.quote()
    local list = M.targets()
    if #list == 0 then return end
    local state = api.get_state()
    local before = state.input:sub(1, state.input_cursor - 1)
    local gap = (before == '' or before:sub(-1) == '\n') and '' or '\n\n'
    api.edit_draft({ text = gap .. M.excerpts(list) .. '\n\n' })
    api.set_mode('i')
end

function M.edit_prompt()
    local list = M.targets()
    local entry = list[1]
    if not entry or entry.kind ~= 'user' then
        ramp.notify('Put the cursor on a prompt to edit it', 'warn')
        return
    end
    api.set_input(entry.text)
    api.set_mode('i')
end

function M.new_session(options)
    local session = M.this_session()
    options = options or {}
    options.cwd = options.cwd or (session and session.cwd or nil)
    api.new_session(options)
end

local settings_after_detach = false

function M.new_session_form()
    if api.get_state().detached then
        api.invoke('session_settings')
    else
        settings_after_detach = true
        api.detach()
    end
end

function M.back()
    local target = api.get_state().detached and current or previous
    if not target then
        ramp.notify('No earlier session to go back to', 'warn')
        return
    end
    api.attach(target)
end

local function jump(step, wanted)
    local state = api.get_state()
    local list = entries(1, state.entry_count)
    local i = (state.entry_cursor or #list + 1) + step
    while list[i] do
        if wanted[list[i].kind] then
            api.set_mode('t')
            api.select_entry(list[i].id)
            return
        end
        i = i + step
    end
end

function M.next(kinds) return function() jump(1, kinds) end end
function M.previous(kinds) return function() jump(-1, kinds) end end

function M.setup()
    if configured then return M end
    configured = true
    current = api.get_state().session_target
    api.on('attached', function(event)
        if current and current ~= event.target then previous = current end
        current = event.target
        if pending and api.get_state().elapsed_ms <= pending.deadline then
            pending.target = event.target
            ready = pending
        end
        pending = nil
    end)
    api.on('session_error', function() pending = nil end)
    api.on('detached', function()
        if settings_after_detach then api.invoke('session_settings') end
        settings_after_detach = false
    end)
    api.on('redraw', function()
        if not ready then return end
        local state = api.get_state()
        if state.session_target ~= ready.target then
            ready = nil
        elseif not (state.loading or state.disconnected or state.busy) then
            if ready.draft then
                api.set_input(ready.draft)
                api.set_mode('i')
            end
            ready = nil
        end
    end)
    return M
end

return M
