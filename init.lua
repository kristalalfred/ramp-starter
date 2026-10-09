local paths = require('config.paths')

ramp.api.add_plugin(paths.packages .. '/ramp-starter/package')
require('ramp_starter').setup(require('config.options'))

for _, plugin in ipairs(require('config.plugins')) do
    ramp.api.add_plugin(plugin.path)
    if plugin.module then require(plugin.module).setup(plugin.opts) end
end

require('config.keymaps')
