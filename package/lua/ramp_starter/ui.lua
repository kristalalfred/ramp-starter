local M = {}
local api = ramp.api

local transcript = {
    compact_tools = true,
    hide_end_turn = false,
    tool_duration = true,
    tool_fold_hint = false,
}
local statusline
local shown = { header = true, statusline = true }
local zen_saved
local notification_line = false
local compact_keys = false

local function say(label, on)
    ramp.notify(label .. (on and ' on' or ' off'))
end

function M.transcript(settings)
    for field, value in pairs(settings or {}) do transcript[field] = value end
    api.set_transcript(transcript)
end

function M.statusline(config)
    statusline = config
    ramp.ui.statusline(shown.statusline and statusline or nil)
end

local function show(part, on)
    shown[part] = on
    if part == 'header' then
        ramp.ui.set('header', not on and { lines = {} } or nil)
    else
        ramp.ui.statusline(on and statusline or nil)
    end
end

function M.flip(field, label)
    return function()
        M.transcript({ [field] = not transcript[field] })
        say(label, transcript[field])
    end
end

function M.toggle(part, label)
    return function()
        show(part, not shown[part])
        say(label, shown[part])
    end
end

function M.zen()
    if zen_saved then
        show('header', zen_saved.header)
        show('statusline', zen_saved.statusline)
        zen_saved = nil
    else
        zen_saved = { header = shown.header, statusline = shown.statusline }
        show('header', false)
        show('statusline', false)
    end
end

function M.notification_style()
    notification_line = not notification_line
    api.set_notifications(notification_line and { style = 'line' } or nil)
    say('Notifications on the notice line', notification_line)
end

function M.key_notation()
    compact_keys = not compact_keys
    ramp.keymap.notation(compact_keys and 'compact' or 'long')
    say('Compact key names', compact_keys)
end

return M
