local M = {}
local configured = false
local api = ramp.api
local branch = require('ramp_starter.branch')

M.asks = {
    { key = 'e', name = 'Explain', prompt = 'Explain this to me in plain terms: what it says, why, and anything I would need to follow it.' },
    { key = 'c', name = 'Critique', prompt = 'Review this critically. What is wrong, risky or missing?' },
    { key = 's', name = 'Summary', prompt = 'Summarize this in a few short bullet points.' },
    { key = 't', name = 'Tests', prompt = 'What tests would show this works, and which would catch it breaking later?' },
}

local HINT = ' C-p pin · C-r quote · C-c stop '

local chat
local pinned = false

local function place(focus)
    if not chat then
        ramp.ui.float('ramp-starter-side', nil)
        ramp.ui.dock('ramp-starter-side', nil)
    elseif pinned then
        ramp.ui.float('ramp-starter-side', nil)
        local width = api.get_state().width
        ramp.ui.dock('ramp-starter-side', { position = 'right', size = math.max(32, math.min(72, math.floor(width * 0.4))) })
        if focus then ramp.ui.focus('ramp-starter-side') end
    else
        ramp.ui.dock('ramp-starter-side', nil)
        ramp.ui.float('ramp-starter-side', {
            relative = 'transcript',
            anchor = 'center',
            width = math.min(100, math.floor(api.get_state().width * 0.8)),
            height = '80%',
            enter = true,
        })
    end
end

local function hide()
    if pinned then ramp.ui.focus() else ramp.ui.float('ramp-starter-side', nil) end
end

local function send(text)
    local conn = api.get_connection(chat.conn)
    if conn and conn.state == 'ready' then
        api.conn_send(chat.conn, text)
    else
        chat.waiting[#chat.waiting + 1] = text
    end
end

local function say(text)
    if chat.context then
        text = chat.context .. text
        chat.context = nil
    end
    send(text)
    chat.scroll = 0
end

local function new_chat(conn, about)
    return { conn = conn, about = about, field = ramp.ui.input(), waiting = {}, scroll = 0, area = 10 }
end

function M.start(question)
    local list = branch.targets()
    if #list == 0 then
        ramp.notify('Nothing to ask about yet', 'warn')
        return
    end
    local here = api.get_connection(0)
    if not here then
        ramp.notify('Attach to a session first', 'warn')
        return
    end
    local session = branch.this_session()
    local launch = { tools = {} }
    if not (session and (session.remote or session.source)) then launch.from = here.name end
    if chat then api.conn_close(chat.conn) end
    chat = new_chat(api.connect({ launch = launch, temporary = true, label = 'ramp-starter-side' }), branch.label(list[1]))
    chat.context = '<context>\nI am asking about this part of our conversation:\n\n'
        .. branch.excerpts(list) .. '\n</context>\n\n'
    if question then say(question) end
    place(true)
end

function M.show()
    if not chat then
        ramp.notify('No side chat is open', 'warn')
        return
    end
    place(true)
end

function M.close()
    if not chat then return end
    local conn = chat.conn
    chat = nil
    api.conn_close(conn)
    place()
end
local function entries(conn)
    if chat.context or conn.state == 'connecting' then return {} end
    if chat.start and chat.revision == conn.transcript_revision then
        return api.transcript_entries({ conn = chat.conn, from = chat.start, limit = 200 }).entries
    end
    local page = api.transcript_entries({ conn = chat.conn, from = -200, limit = 200 })
    for i = #page.entries, 1, -1 do
        local entry = page.entries[i]
        if entry.kind == 'user' and entry.text:find('^<context>') then
            chat.start, chat.revision = entry.index, conn.transcript_revision
            return { table.unpack(page.entries, i) }
        end
    end
    return {}
end

local function latest_reply()
    local conn = api.get_connection(chat.conn)
    local list = conn and entries(conn) or {}
    for i = #list, 1, -1 do
        if list[i].kind == 'assistant' then return list[i] end
    end
end

local function quote()
    local reply = latest_reply()
    if not reply then
        ramp.notify('No reply to quote yet', 'warn')
        return
    end
    local state = api.get_state()
    local before = state.input:sub(1, state.input_cursor - 1)
    local gap = (before == '' or before:sub(-1) == '\n') and '' or '\n\n'
    api.edit_draft({ text = gap .. 'From a side chat:\n> ' .. reply.text:gsub('\n', '\n> ') .. '\n\n' })
    hide()
    api.set_mode('i')
end

local function wrapped(rows, text, width, hl)
    local code = false
    for _, line in ipairs(ramp.ui.wrap(text, width)) do
        local fence = line:match('^%s*```') ~= nil
        if fence then code = not code end
        rows[#rows + 1] = { { text = line, hl = hl or ((code or fence) and 'code' or nil) } }
    end
end

local function band(rows, text, width)
    for _, line in ipairs(ramp.ui.wrap(text, math.max(1, width - 2))) do
        local pad = math.max(0, width - 2 - utf8.len(line))
        rows[#rows + 1] = { { text = '› ', hl = 'user_marker' }, { text = line .. string.rep(' ', pad), hl = 'user' } }
    end
end

local function entry_rows(rows, entry, width)
    if entry.kind == 'user' then
        band(rows, (entry.text:gsub('^<context>.-</context>%s*', '')), width)
    elseif entry.kind == 'assistant' then
        wrapped(rows, entry.text, width)
    elseif (entry.kind == 'note' and entry.text ~= 'finished (EndTurn)') or entry.kind == 'aside' then
        wrapped(rows, entry.text, width, 'note')
    else
        return
    end
    rows[#rows + 1] = ''
end

local function chat_rows(conn, width)
    local rows = {}
    if chat.context then
        wrapped(rows, 'About: ' .. chat.about, width, 'muted')
        rows[#rows + 1] = ''
        wrapped(rows, 'Ask below. The copy has the conversation but no tools.', width, 'muted')
        return rows
    end
    local list = entries(conn)
    for _, entry in ipairs(list) do entry_rows(rows, entry, width) end
    local last = list[#list]
    if conn.error then
        wrapped(rows, conn.error, width, 'error')
    elseif conn.state == 'connecting' or #chat.waiting > 0 then
        wrapped(rows, 'Starting a copy of the session…', width, 'muted')
    elseif conn.busy and not (last and last.live) then
        wrapped(rows, 'Thinking…', width, 'muted')
    end
    return rows
end

local function rule(width)
    local room = width - utf8.len(HINT) - 1
    if room < 2 then return { { text = string.rep('─', width), hl = 'muted' } } end
    return { { text = string.rep('─', room) .. HINT .. '─', hl = 'muted' } }
end

local function render(ctx)
    if not chat then return nil end
    local width, inner = math.max(1, ctx.width - 2), math.max(3, ctx.height - 2)
    local conn = api.get_connection(chat.conn)
    local field = chat.field:wrap(width)
    local field_rows = math.max(1, math.min(#field.rows, inner // 3))
    local first = math.max(1, math.min(field.cursor.row - field_rows + 1, #field.rows - field_rows + 1))
    local area = inner - field_rows - 1
    chat.area = area

    local rows = conn and chat_rows(conn, width) or { { { text = 'The side chat was closed', hl = 'error' } } }
    chat.scroll = math.max(0, math.min(chat.scroll, #rows - area))
    local lines = {}
    local top = math.max(1, #rows - area - chat.scroll + 1)
    for i = top, math.min(#rows, top + area - 1) do lines[#lines + 1] = rows[i] end
    while #lines < area do lines[#lines + 1] = '' end
    lines[#lines + 1] = rule(width)
    for i = first, first + field_rows - 1 do lines[#lines + 1] = field.rows[i] or '' end

    return {
        border = true,
        border_kind = 'rounded',
        border_hl = ctx.focused and 'RampStarterSideBorder' or 'muted',
        title = ' Side chat · ' .. chat.about .. ' ',
        title_hl = ctx.focused and 'RampStarterSideTitle' or 'muted',
        lines = lines,
        cursor = ctx.focused and { area + 1 + field.cursor.row - first + 1, field.cursor.col } or nil,
    }
end

local function key(event)
    if not chat then return false end
    local k = event.key
    if k == '<CR>' then
        local text = chat.field:text()
        if text:match('%S') then
            say(text)
            chat.field:set('')
        end
    elseif k == '<Esc>' then
        hide()
    elseif k == '<C-p>' then
        pinned = not pinned
        place(true)
    elseif k == '<C-r>' then
        quote()
    elseif k == '<C-c>' then
        pcall(api.conn_cancel, chat.conn)
    elseif k == '<PageUp>' or k == '<PgUp>' then
        chat.scroll = chat.scroll + math.max(1, chat.area // 2)
    elseif k == '<PageDown>' or k == '<PgDn>' then
        chat.scroll = math.max(0, chat.scroll - math.max(1, chat.area // 2))
    else
        chat.field:key(event)
    end
    return true
end

local function mouse(event)
    if not chat then return false end
    if event.action == 'scroll_up' then
        chat.scroll = chat.scroll + 3
    elseif event.action == 'scroll_down' then
        chat.scroll = math.max(0, chat.scroll - 3)
    else
        return false
    end
    return true
end

function M.setup()
    if configured then return M end
    configured = true
    api.set_hl('RampStarterSideBorder', { fg = '#89b4fa' })
    api.set_hl('RampStarterSideTitle', { fg = '#89b4fa', bold = true })
    ramp.ui.register_view('ramp-starter-side', {
        render = render,
        key = key,
        mouse = mouse,
        paste = function(event) return chat ~= nil and chat.field:paste(event) end,
    })
    api.on('connection', function(event)
        if not chat or event.conn ~= chat.conn then return end
        if event.state == 'ready' then
            local waiting = chat.waiting
            chat.waiting = {}
            for _, text in ipairs(waiting) do api.conn_send(chat.conn, text) end
        elseif event.state == 'closed' then
            chat = nil
            place()
        end
    end)
    for _, conn in ipairs(api.get_connections()) do
        if conn.label == 'ramp-starter-side' and not conn.current then
            if chat then api.conn_close(chat.conn) end
            chat = new_chat(conn.id, 'from before the reload')
        end
    end
    return M
end

return M
