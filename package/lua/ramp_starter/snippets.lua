local M = {}
local configured = false
local api = ramp.api

M.snippets = {
    { name = 'review', key = 'r', desc = 'Review changes',
      body = 'Review $1 for bugs, unclear code and missing tests. List what you find by severity and change nothing yet.$0' },
    { name = 'plan', key = 'p', desc = 'Plan before acting',
      body = 'Before changing anything, write a short plan for: $1\n\nName the files you expect to touch and how you will check the result, then wait for my go-ahead.$0' },
    { name = 'fix', key = 'f', desc = 'Fix a failure',
      body = 'This fails:\n\n```\n$1\n```\n\nFind the cause, fix it, and show me how you checked.$0' },
    { name = 'how', key = 'h', desc = 'How does it work',
      body = 'How does $1 work? Start from the entry point and name the functions involved.$0' },
    { name = 'test', key = 't', desc = 'Write tests',
      body = 'Write tests for $1 that cover $2. Run them and show me the output.$0' },
    { name = 'commit', key = 'c', desc = 'Commit the work',
      body = 'Commit what we changed with a one-line message$1.$0' },
    { name = 'brief', key = 'b', desc = 'Short answer',
      body = '$1\n\nAnswer in at most three sentences.$0' },
}

local by_name = {}
for _, snippet in ipairs(M.snippets) do by_name[snippet.name] = snippet end

local active
local move_to

local function parse(body)
    local pieces, at, length, last = {}, {}, 0, 1
    for start, digit, after in body:gmatch('()%$(%d)()') do
        local piece = body:sub(last, start - 1)
        pieces[#pieces + 1] = piece
        length = length + #piece
        at[tonumber(digit)] = length
        last = after
    end
    pieces[#pieces + 1] = body:sub(last)
    local text = table.concat(pieces)
    local stops = {}
    for n = 1, 9 do
        if at[n] then stops[#stops + 1] = at[n] end
    end
    stops[#stops + 1] = at[0] or #text
    return text, stops
end

local function insert(snippet, from, to)
    local text, stops = parse(snippet.body)
    local length = #api.get_state().input - (to - from) + #text
    for i, offset in ipairs(stops) do stops[i] = from + offset end
    api.edit_draft({ from = from, to = to, text = text })
    move_to = stops[1]
    api.set_mode('i')
    active = #stops > 1 and { stops = stops, index = 1, length = length } or nil
end

function M.expand(name)
    local snippet = by_name[name]
    if not snippet then
        ramp.notify('No snippet called ' .. name, 'warn')
        return
    end
    local cursor = api.get_state().input_cursor
    insert(snippet, cursor, cursor)
end

local function jump()
    local length = #api.get_state().input
    local shift = length - active.length
    active.index = active.index + 1
    for i = active.index, #active.stops do active.stops[i] = active.stops[i] + shift end
    active.length = length
    local stop = active.stops[active.index]
    if active.index == #active.stops then active = nil end
    if stop > length + 1 or not pcall(api.edit_draft, { cursor = stop }) then active = nil end
end

function M.expand_or_jump()
    if active then return jump() end
    local state = api.get_state()
    local before = state.input:sub(1, state.input_cursor - 1)
    local word = before:match('(%w+)$')
    if word and by_name[word] then
        insert(by_name[word], state.input_cursor - #word, state.input_cursor)
        return
    end
    return false
end

function M.setup()
    if configured then return M end
    configured = true
    api.on('before_submit', function() active = nil end)
    api.on('redraw', function()
        if not move_to then return end
        local stop = move_to
        move_to = nil
        if stop > #api.get_state().input + 1 or not pcall(api.edit_draft, { cursor = stop }) then
            active = nil
        end
    end)
    api.register_command('starter-snippet', {
        desc = 'Put a prompt snippet in the draft',
        args = 'NAME',
        run = function(args) M.expand(args) end,
        complete = function()
            local items = {}
            for _, snippet in ipairs(M.snippets) do
                items[#items + 1] = { text = snippet.name, desc = snippet.desc }
            end
            return items
        end,
    })
    return M
end

return M
