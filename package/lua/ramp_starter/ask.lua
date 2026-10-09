local M = {}
local configured = false

local active

local function close()
    active = nil
    ramp.ui.float('ramp-starter-ask', nil)
end

local function open(state)
    active = state
    local width = ramp.api.get_state().width
    ramp.ui.float('ramp-starter-ask', {
        relative = 'transcript',
        anchor = 'bottom_center',
        width = math.max(20, math.min(width - 4, 72)),
        height = 'auto',
        enter = true,
    })
end

local function key(event)
    if not active then return false end
    local k, done = event.key, active.on_done
    if active.confirm then
        close()
        if k == 'y' or k == 'Y' then done() end
    elseif k == '<CR>' then
        local answer = active.field:text()
        close()
        done(answer)
    elseif k == '<Esc>' then
        close()
    else
        active.field:key(event)
    end
    return true
end

local function frame(lines)
    return {
        border = true,
        border_kind = 'rounded',
        border_hl = 'RampStarterAskBorder',
        title = ' ' .. active.prompt .. ' ',
        title_hl = 'RampStarterAskLabel',
        lines = lines,
    }
end

local function render(ctx)
    if not active then return nil end
    if active.confirm then
        return frame({ { { text = 'y', hl = 'RampStarterAskLabel' }, { text = ' yes · any other key no', hl = 'muted' } } })
    end
    local wrapped = active.field:wrap(math.max(1, ctx.width - 2))
    local view = frame(wrapped.rows)
    view.cursor = ctx.focused and { wrapped.cursor.row, wrapped.cursor.col } or nil
    return view
end

function M.input(opts, on_done)
    open({ prompt = opts.prompt or 'Answer', field = ramp.ui.input(opts.default), on_done = on_done })
end

function M.confirm(question, on_yes)
    open({ prompt = question, confirm = true, on_done = on_yes })
end

function M.setup()
    if configured then return M end
    configured = true
    ramp.api.set_hl('RampStarterAskBorder', { fg = '#f9e2af' })
    ramp.api.set_hl('RampStarterAskLabel', { fg = '#f9e2af', bold = true })
    ramp.ui.register_view('ramp-starter-ask', {
        render = render,
        key = key,
        paste = function(event)
            if not active or active.confirm then return false end
            return active.field:paste((event.text:gsub('%c', ' ')))
        end,
    })
    return M
end

return M
