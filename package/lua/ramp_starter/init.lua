local M = {}
local configured = false
local options = {
    theme = true, transcript = true, composer = true, statusline = true,
    draft_policy = true, workflows = true, keymaps = true, side = true,
}

function M.setup(opts)
    if configured then return M end
    opts = opts or {}
    for key in pairs(opts) do
        if not options[key] then error('unknown ramp_starter option: ' .. key, 2) end
    end

    require('ramp_starter.defaults').setup(opts)
    if opts.workflows ~= false then
        require('ramp_starter.ask').setup()
        require('ramp_starter.branch').setup()
        require('ramp_starter.snippets').setup()
        if opts.side then require('ramp_starter.side').setup() end
        if opts.keymaps ~= false then
            require('ramp_starter.keys').setup({ side = opts.side })
        end
    end
    configured = true
    return M
end

return M
