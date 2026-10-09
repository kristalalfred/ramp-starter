local data = os.getenv('XDG_DATA_HOME')
if not data or data:sub(1, 1) ~= '/' then
    data = assert(os.getenv('HOME'), 'HOME must be set') .. '/.local/share'
end

return { packages = data .. '/ramp/plugins' }
