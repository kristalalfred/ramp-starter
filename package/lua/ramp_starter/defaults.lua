local M = {}
local api = ramp.api
local ui = require('ramp_starter.ui')

local modes = {
    i = { name = 'INSERT', color = '#a6e3a1', cursor = 'bar' },
    n = { name = 'NORMAL', color = '#89b4fa', cursor = 'block' },
    t = { name = 'TRANSCRIPT', color = '#cba6f7', cursor = 'block' },
}
local function mode(state) return modes[state.mode] or modes.i end

local function compact_tokens(tokens)
    if tokens < 10000 then return tostring(tokens) end
    if tokens < 1000000 then return string.format('%.1fk', tokens / 1000) end
    return string.format('%.1fM', tokens / 1000000)
end

local function cache_usage(state)
    local usage = state.usage
    if not usage then return 'Cache: unavailable' end
    return string.format(
        'Cache: %s read · %s written',
        compact_tokens(usage.cache_read),
        compact_tokens(usage.cache_write)
    )
end

function M.setup(opts)
    if opts.draft_policy ~= false then
        api.set_draft_policy(type(opts.draft_policy) == 'table' and opts.draft_policy or { new_session = 'history', session = 'restore' })
    end
    if opts.transcript ~= false then
        ramp.ui.set('empty', nil)

        ui.transcript({
            compact_tools = true,
            group_tools = true,
            group_thinking = true,
            smooth_output = true,
            hide_end_turn = true,
        })
        if type(opts.transcript) == 'table' then ui.transcript(opts.transcript) end
    end
    if opts.theme ~= false then
        ramp.ui.theme({
            user = { fg = '#cdd6f4', bg = '#313244', bold = true },
            user_marker = { fg = '#89b4fa' },
            assistant = { fg = '#cdd6f4' },
            code = { fg = '#fab387' },
            reasoning = { fg = '#737b91', dim = true },
            tool = { fg = '#a6adc8' },
            tool_input = { fg = '#cdd6f4' },
            tool_output = { fg = '#737b91' },
            tool_running = { fg = '#89b4fa' },
            tool_succeeded = { fg = '#6c7086' },
            tool_failed = { fg = '#f38ba8' },
            gutter = { fg = '#6c7086' },
            note = { fg = '#6c7086' },
            delivery = { fg = '#6c7086' },
            delivery_glow = { fg = '#89b4fa' },
            transcript_cursor = { bg = '#39435f' },
            transcript_marked = { bg = '#443c5a' },
            transcript_cursor_marked = { bg = '#63547e' },
            selected = { fg = '#11111b', bg = '#89b4fa', bold = true },
            panel_border = { fg = '#45475a' },
            panel_title = { fg = '#89b4fa', bold = true },
            panel_section = { fg = '#74c7ec', bold = true },
            panel_marker = { fg = '#89b4fa', bold = true },
            panel_count = { fg = '#6c7086' },
            panel_note = { fg = '#7f849c' },
            session_live = { fg = '#a6e3a1', bold = true },
            session_recent = { fg = '#89b4fa' },
            session_other = { fg = '#fab387' },
            session_root = { fg = '#cdd6f4', bold = true },
        })

    end
    if opts.composer ~= false then
        for letter, spec in pairs(modes) do
            api.set_hl('Input' .. letter, { fg = spec.color })
        end

        api.on('redraw', function()
            local state = api.get_state()
            api.set_composer({
                cursor = mode(state).cursor,
                border_hl = 'Input' .. (modes[state.mode] and state.mode or 'i'),
            })
        end)

    end
    if opts.statusline ~= false then
        ui.statusline({
            region = 'bottom',
            separator = 'slant',
            color = { fg = '#cdd6f4', bg = 'reset' },
            fields = {
                {
                    text = function(s) return mode(s).name end,
                    color = function(s) return { fg = '#181825', bg = mode(s).color, bold = true } end,
                },
                {
                    text = function(s) return s.model end,
                    color = { bg = '#313244' },
                },
                {
                    text = function(s) return s.activity end,
                    color = { bg = '#45475a' },
                },
                {
                    text = function(s) return 'Queued: ' .. s.queued end,
                    cond = function(s) return s.queued > 0 end,
                    color = { fg = '#181825', bg = '#f9e2af' },
                },
                {
                    text = cache_usage,
                    color = { bg = '#3b4f4c' },
                },
                {
                    text = function(s) return s.storage end,
                    color = { bg = '#313244' },
                },
            },
        })
    end
end

return M
