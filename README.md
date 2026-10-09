# Ramp starter

A starter configuration for Ramp with a shared Lua setup and the Ronna client
plugin. Binaries are installed separately. Lua packages are installed through
Git and pinned to release tags.

## Install

Install Git, Ramp, and the Ronna CLI first. Ramp must support the current Lua API,
including draft recovery and multiple connections. This setup was verified with
Ramp revision `b5642c9` and Ronna revision `d62e7b9`.

The Homebrew formulae for Ramp and Ronna are not published yet. Once available,
the tap will distribute binaries only.

Back up an existing configuration before cloning. These commands use the default
XDG paths; substitute your configured paths if you use `XDG_CONFIG_HOME`.

```sh
if [ -e ~/.config/ramp ]; then
  mv ~/.config/ramp ~/.config/ramp.backup-$(date +%Y%m%d-%H%M%S)
fi
git clone https://github.com/KristalAlfred/ramp-starter ~/.config/ramp
sh ~/.config/ramp/install.sh
rm -rf ~/.config/ramp/.git
ramp sessions
```

The starter files are now yours. Add them to your own dotfiles repository if you
want to track customizations. Saved sessions, drafts, credentials, and other
plugins do not need to be moved or deleted.

The default Ronna server is `https://ronna.svartkonst.com`. An invited account is
required. Ramp opens Ronna's email sign-in dialog when you are signed out. You can
also sign in explicitly with:

```sh
ronna --control https://ronna.svartkonst.com login --email you@example.com
```

## Files and loading order

| File | Purpose |
| --- | --- |
| `init.lua` | Loads shared defaults, configured plugins, then personal keymaps |
| `lua/config/options.lua` | Enables or disables shared features |
| `lua/config/plugins.lua` | Plugin paths, setup modules, and options |
| `lua/config/keymaps.lua` | Personal keymaps and final UI overrides |
| `package/lua/ramp_starter/` | Maintained shared setup, installed as a separate Git checkout |

`install.sh` clones the shared setup and [Ronna plugin](https://github.com/KristalAlfred/ronna-ramp)
into `$XDG_DATA_HOME/ramp/plugins`, or `~/.local/share/ramp/plugins` when
`XDG_DATA_HOME` is unset or relative. The configuration registers those packages
with `ramp.api.add_plugin`; they are not automatically enabled in other Ramp
configurations. Ramp still loads packages in its usual `pack/*/start/*` paths.

Ronna's startup file runs after the configuration. Its `setup` is idempotent, so
the starter's explicit options remain in effect. Other plugins' startup files
also run after the configuration; their own setup conventions determine whether
they replace a personal override. `:config-check` reports loaded files and errors.

## Customize

Set `theme`, `transcript`, `composer`, `statusline`, `draft_policy`, `workflows`, or
`keymaps` to `false` in `lua/config/options.lua` to disable that feature.
`transcript` and `draft_policy` also accept settings tables. Disabling `workflows`
disables the shared workflow keymaps. `side = true` enables optional side chats;
they launch a local agent and require a locally configured runtime and provider.

The setup includes compact transcripts, a mode-colored composer, a status line,
prompt snippets, branching helpers, and Space-prefixed keymaps. The shared
modules and custom views are namespaced. Setup functions run once per
configuration load. Nothing selects a model or starts an agent during loading.

For example, put this in `lua/config/keymaps.lua`:

```lua
ramp.keymap.set('n', '<C-y>', 'sessions', { desc = 'Switch session' })
ramp.ui.theme({ assistant = { fg = '#ffffff' } })
```

To add a plugin, clone it into a directory you control and add an entry to
`lua/config/plugins.lua`:

```lua
{
  path = '~/src/ramp-wordcount',
  module = 'wordcount',
  opts = {},
},
```

Omit `module` for a package that only has `plugin/*.lua` startup files. Removing
an entry disables that package for this configuration, unless it is also in a
`pack/*/start/*` directory. Ronna can be removed the same way. Set
`default_ui = false` in its `opts` to use another session interface.

## Update Lua packages

Removing the starter's `.git` does not affect the separate package checkouts.
To fetch the versions configured by the installer:

```sh
sh ~/.config/ramp/install.sh --update
```

The initial versions are `v0.1.0` for both packages. To select a later compatible
pair, edit the defaults in your installer or supply `RAMP_STARTER_REF` and
`RONNA_RAMP_REF`. Updates preserve the starter files and refuse dirty package
checkouts or unexpected Git origins. Third-party plugin updates are managed
through their own Git checkouts.

The installer also accepts `RAMP_STARTER_REPOSITORY` and `RONNA_RAMP_REPOSITORY`
for forks or local verification. Downloaded Lua is trusted local code.

## Development

`just check` checks the installer, exercises fresh installation and updates in
temporary directories, and verifies composition and reload in the installed
Ramp. It requires Python 3, Git, ShellCheck, tmux, Ramp, and the Ronna CLI.

`just run` opens this starter using installed packages. Publishing a new package
version requires updating the installer's defaults and verifying the selected
pair before tagging it.
