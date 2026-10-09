local paths = require('config.paths')

return {
    {
        path = paths.packages .. '/ronna',
        module = 'ronna',
        opts = {
            args = { '--control', 'https://ronna.svartkonst.com' },
            launch_args = { '--provider-default-resources' },
            network_mode = 'selected-integrations',
        },
    },
}
