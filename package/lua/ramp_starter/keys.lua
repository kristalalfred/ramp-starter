local api = ramp.api
local ask = require('ramp_starter.ask')
local branch = require('ramp_starter.branch')
local side = require('ramp_starter.side')
local snippets = require('ramp_starter.snippets')
local ui = require('ramp_starter.ui')

local function map(modes, lhs, rhs, desc)
    for mode in modes:gmatch('%a') do
        ramp.keymap.set(mode, lhs, rhs, { desc = desc })
    end
end

local function group(modes, lhs, name)
    for mode in modes:gmatch('%a') do ramp.keymap.group(mode, lhs, name) end
end

local function cmd(line)
    return function() api.invoke('command', line) end
end

local function slug(text)
    return ((text or 'conversation'):lower():gsub('[^%w]+', '-'):gsub('^%-+', ''):gsub('%-+$', ''))
end

local M = {}
local configured = false

function M.setup(opts)
    if configured then return M end
    configured = true
    opts = opts or {}
    for _, scope in ipairs({ 'd', 'sessions' }) do
        ramp.keymap.set(scope, '<Tab>', 'next_provider', { desc = 'Next session provider' })
        ramp.keymap.set(scope, '<S-Tab>', 'previous_provider', { desc = 'Previous session provider' })
    end

    local NT = 'nt'

    map('t', '<Tab>', 'toggle', 'Mark the entry')
    map('t', 'q', 'normal', 'Leave transcript mode')
    map('t', ']p', branch.next({ user = true }), 'Next prompt')
    map('t', '[p', branch.previous({ user = true }), 'Previous prompt')
    map('t', ']r', branch.next({ assistant = true }), 'Next reply')
    map('t', '[r', branch.previous({ assistant = true }), 'Previous reply')
    map('t', ']t', branch.next({ tool = true }), 'Next tool call')
    map('t', '[t', branch.previous({ tool = true }), 'Previous tool call')

    map(NT, '<Leader><Space>', 'files', 'Find a file')
    map(NT, '<Leader>,', 'sessions', 'Switch session')
    map(NT, '<Leader>/', 'search', 'Search the conversation')
    map(NT, '<Leader>n', 'notifications', 'Notifications')
    map('d', '<Leader>n', 'new_session', 'New session with defaults')

    group(NT, '<Leader>a', 'agent')
    map(NT, '<Leader>ac', cmd('cancel'), 'Cancel the run and the queue')
    map(NT, '<Leader>am', cmd('session-model'), 'Current session model')
    map(NT, '<Leader>ak', cmd('compact'), 'Compact the context')
    map(NT, '<Leader>as', 'send_mode', 'Cycle queue / inject / steer')
    map(NT, '<Leader>aq', 'queue', 'Queued prompts')
    map(NT, '<Leader>ai', 'status', 'Session info')
    map(NT, '<Leader>ap', function()
        local auto = api.get_state().permissions == 'auto tools'
        api.invoke('command', 'permissions ' .. (auto and 'ask' or 'auto'))
        ramp.notify(auto and 'Asking before tools' or 'Tools run without asking')
    end, 'Toggle ask / auto tools')
    group(NT, '<Leader>ae', 'effort')
    for _, level in ipairs({ { 'l', 'low' }, { 'm', 'medium' }, { 'h', 'high' }, { 'x', 'xhigh' }, { 'M', 'max' } }) do
        map(NT, '<Leader>ae' .. level[1], cmd('effort ' .. level[2]), 'Effort ' .. level[2])
    end

    group('ntd', '<Leader>s', 'sessions')
    map('ntd', '<Leader>sb', branch.back, 'Back to the previous session')
    map(NT, '<Leader>sl', 'sessions', 'List sessions')
    map(NT, '<Leader>sd', 'detach', 'Detach')
    map('ntd', '<Leader>sn', branch.new_session, 'New session here')
    map('ntd', '<Leader>sm', cmd('model'), 'Default model until exit')
    map('ntd', '<Leader>ss', branch.new_session_form, 'New session with settings')
    map(NT, '<Leader>sf', function() api.fork() end, 'Fork the whole session')
    map(NT, '<Leader>sF', function()
        ask.input({ prompt = 'Fork titled' }, function(title) api.fork(title) end)
    end, 'Fork with a title')
    map(NT, '<Leader>sr', function()
        ask.input({ prompt = 'Title', default = api.get_state().title }, function(title)
            api.invoke('command', 'title ' .. title)
        end)
    end, 'Rename')
    map(NT, '<Leader>sR', 'refresh', 'Refresh the list')
    map(NT, '<Leader>sD', function()
        ask.confirm('Stop this agent? Its session is saved.', cmd('stop'))
    end, 'Stop the agent')

    group(NT, '<Leader>c', 'conversation')
    map(NT, '<Leader>cy', cmd('copy reply'), 'Copy the latest reply')
    map(NT, '<Leader>ct', 'transcript', 'Transcript mode')
    map(NT, '<Leader>ce', function()
        local state = api.get_state()
        local default = ('%s/%s-%s.md'):format(
            os.getenv('HOME'), os.date('%Y-%m-%d'), slug(state.display_label))
        ask.input({ prompt = 'Export to', default = default }, function(path)
            if path ~= '' then api.invoke('command', 'export ' .. path) end
        end)
    end, 'Export as Markdown')
    map(NT, '<Leader>cX', function()
        ask.confirm('Clear the conversation context?', cmd('clear'))
    end, 'Clear the context')

    group(NT, '<Leader>f', 'find')
    map(NT, '<Leader>ff', 'files', 'Files')
    map(NT, '<Leader>fh', 'history_search', 'Prompt history')
    map(NT, '<Leader>fs', 'search', 'Search the conversation')
    map(NT, '<Leader>fc', 'commands', 'Commands')
    map(NT, '<Leader>fn', 'notifications', 'Notifications')

    group(NT, '<Leader>m', 'message')
    map(NT, '<Leader>mf', branch.branch_here, 'Branch from here')
    if opts.side then
        map(NT, '<Leader>ma', function() side.start() end, 'Ask about it on the side')
        for _, one in ipairs(side.asks) do
            map(NT, '<Leader>m' .. one.key, function() side.start(one.prompt) end, one.name .. ' on the side')
        end
        map(NT, '<Leader>mm', side.show, 'Show the side chat')
        map(NT, '<Leader>mx', side.close, 'Close the side chat')
    end
    map(NT, '<Leader>mq', branch.quote, 'Quote in the draft')
    map(NT, '<Leader>mp', branch.edit_prompt, 'Edit the prompt again')

    group(NT, '<Leader>t', 'tools')
    map(NT, '<Leader>tt', 'toggle_tools', 'Cycle transcript detail')
    map(NT, '<Leader>tn', 'next_tool', 'Next call')
    map(NT, '<Leader>tp', 'previous_tool', 'Previous call')
    map(NT, '<Leader>td', cmd('diff'), 'Latest edit')
    map(NT, '<Leader>ty', cmd('copy tool'), 'Copy the call output')
    map(NT, '<Leader>ta', 'approval', 'Approval prompt')

    group(NT, '<Leader>p', 'prompts')
    for _, snippet in ipairs(snippets.snippets) do
        map(NT, '<Leader>p' .. snippet.key, function() snippets.expand(snippet.name) end, snippet.desc)
    end
    map('i', '<C-n>', snippets.expand_or_jump, 'Expand a snippet, or its next stop')

    group(NT, '<Leader>u', 'ui')
    map(NT, '<Leader>ut', ui.flip('compact_tools', 'Compact tool calls'), 'Compact tool calls')
    map(NT, '<Leader>ue', ui.flip('hide_end_turn', 'Hiding end-of-turn notes'), 'Hide end-of-turn notes')
    map(NT, '<Leader>ud', ui.flip('tool_duration', 'Call durations'), 'Call durations')
    map(NT, '<Leader>uf', ui.flip('tool_fold_hint', 'Fold hints'), 'Fold hints')
    map(NT, '<Leader>uh', ui.toggle('header', 'Header'), 'Header')
    map(NT, '<Leader>us', ui.toggle('statusline', 'Status line'), 'Status line')
    map(NT, '<Leader>uz', ui.zen, 'Zen')
    map(NT, '<Leader>un', function() api.dismiss_notification() end, 'Dismiss notifications')
    map(NT, '<Leader>uN', ui.notification_style, 'Notifications as a line')
    map(NT, '<Leader>uk', ui.key_notation, 'Compact key names')

    group('ntd', '<Leader>l', 'lua config')
    map('ntd', '<Leader>lc', cmd('config-check'), 'Check the config')
    map('ntd', '<Leader>lr', 'reload_config', 'Reload the config')

    group('ntd', '<Leader>q', 'quit')
    map('ntd', '<Leader>qq', 'quit', 'Quit, saving the draft')

end

return M
