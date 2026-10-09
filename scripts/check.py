import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time


root = Path(__file__).resolve().parents[1]


def run(*args, cwd=None, env=None, success=True):
    result = subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True)
    if (result.returncode == 0) != success:
        raise AssertionError(result.stdout + result.stderr)
    return result.stdout + result.stderr


def git(path, *args):
    return run("git", "-C", str(path), *args)


def seed(source, destination):
    shutil.copytree(source, destination, ignore=shutil.ignore_patterns(".git", "__pycache__", ".DS_Store"))
    git(destination, "init", "-b", "main")
    git(destination, "add", ".")
    git(destination, "-c", "user.name=Starter check", "-c", "user.email=check@example.com", "commit", "-m", "seed")
    git(destination, "tag", "v0.1.0")


for executable in ("git", "tmux", "ramp", "ronna"):
    if not shutil.which(executable):
        raise SystemExit("Required executable is missing: " + executable)

with tempfile.TemporaryDirectory(prefix="ramp-starter-check-") as directory:
    temporary = Path(directory)
    starter_source = temporary / "starter-source"
    ronna_source = temporary / "ronna-source"
    seed(root, starter_source)
    adapter = Path(os.environ.get("RONNA_RAMP_SOURCE", str(root.parent / "ronna-ramp")))
    if not adapter.exists():
        adapter = temporary / "adapter"
        run("git", "clone", "--depth", "1", "--branch", "v0.1.0", "https://github.com/KristalAlfred/ronna-ramp.git", str(adapter))
    seed(adapter, ronna_source)
    config = temporary / "config" / "ramp"
    config.parent.mkdir()
    run("git", "clone", str(starter_source), str(config))
    shutil.rmtree(config / ".git")
    data = temporary / "data with spaces"
    home = temporary / "home"
    home.mkdir()
    environment = {
        **os.environ,
        "HOME": str(home),
        "XDG_DATA_HOME": str(data),
        "XDG_CONFIG_HOME": str(config.parent),
        "RAMP_STARTER_REPOSITORY": starter_source.as_uri(),
        "RONNA_RAMP_REPOSITORY": ronna_source.as_uri(),
    }
    installer = ("sh", str(config / "install.sh"))
    run(*installer, env=environment)
    run(*installer, env=environment)
    run(*installer, "--unknown", env=environment, success=False)
    packages = data / "ramp/plugins"
    for name in ("ramp-starter", "ronna"):
        assert (packages / name / ".git").is_dir()
    personal = config / "lua/config/keymaps.lua"
    personal.write_text("ramp.api.set_notifications({ min_level = 'info' })\nramp.keymap.set('d', '<C-y>', function() ramp.notify('PERSONAL OVERRIDE') end)\n")
    personal_text = personal.read_text()
    for source in (starter_source, ronna_source):
        (source / "release-marker").write_text("updated\n")
        git(source, "add", "release-marker")
        git(source, "-c", "user.name=Starter check", "-c", "user.email=check@example.com", "commit", "-m", "update")
        git(source, "tag", "v0.1.1")
    updated = {**environment, "RAMP_STARTER_REF": "v0.1.1", "RONNA_RAMP_REF": "v0.1.1"}
    run(*installer, env=updated, success=False)
    run(*installer, "--update", env=updated)
    assert personal.read_text() == personal_text
    for name in ("ramp-starter", "ronna"):
        assert (packages / name / "release-marker").read_text() == "updated\n"
    dirty = packages / "ronna/lua/ronna/init.lua"
    original = dirty.read_text()
    dirty.write_text(original + "\nlocal user_change = true\n")
    output = run(*installer, "--update", env=updated, success=False)
    assert "local changes" in output
    assert dirty.read_text().endswith("local user_change = true\n")
    dirty.write_text(original)
    assert "Unexpected origin" in run(*installer, env={**updated, "RONNA_RAMP_REPOSITORY": starter_source.as_uri()}, success=False)
    bad = temporary / "bad"
    (bad / "ramp/plugins/ramp-starter").mkdir(parents=True)
    assert "Not a Git checkout" in run(*installer, env={**environment, "XDG_DATA_HOME": str(bad)}, success=False)

    extra = temporary / "extra"
    (extra / "lua").mkdir(parents=True)
    (extra / "lua/ui.lua").write_text("error('unnamespaced module collision')\n")
    (extra / "lua/extra.lua").write_text(
        "local M = {}\nfunction M.setup()\n"
        "ramp.api.register_command('starter-probe', { desc = 'Composition probe', run = function() ramp.notify('PLUGIN COMPOSED') end })\n"
        "ramp.keymap.set('d', '<C-y>', function() ramp.notify('PLUGIN KEYMAP') end)\n"
        "end\nreturn M\n"
    )
    plugin_config = config / "lua/config/plugins.lua"
    plugin_config.write_text(
        "local paths = require('config.paths')\nreturn {\n"
        "{ path = paths.packages .. '/ronna', module = 'ronna', opts = { signin_ui = false, args = { '--control', 'http://127.0.0.1:9' } } },\n"
        "{ path = " + repr(str(extra)) + ", module = 'extra' },\n}\n"
    )
    with (config / "init.lua").open("a") as stream:
        stream.write("\nrequire('ramp_starter').setup({ side = true })\n")
    session = "starter-check-" + str(os.getpid())

    def tmux(*args):
        return run("tmux", "-L", session, *args)

    def screen():
        return tmux("capture-pane", "-p", "-t", "starter")

    def wait_for(text):
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline:
            current = screen()
            if text in current:
                return current
            time.sleep(0.1)
        raise AssertionError("Missing " + text + "\n" + screen())

    def command(text):
        tmux("send-keys", "-t", "starter", ":")
        tmux("send-keys", "-t", "starter", "-l", "--", text)
        tmux("send-keys", "-t", "starter", "Enter")

    runtime_env = {
        "HOME": str(home),
        "XDG_DATA_HOME": str(data),
        "XDG_CONFIG_HOME": str(config.parent),
        "RAMP_CONFIG": str(config / "init.lua"),
        "RONNA_CREDENTIALS": str(temporary / "credentials.toml"),
        "RONNA_CLIENT_CONFIG": str(temporary / "ronna.toml"),
        "EXO_CONFIG": str(temporary / "exo.toml"),
        "EXO_RUNTIME_DIR": str(temporary / "runtime"),
        "EXO_SESSION_DIR": str(temporary / "sessions"),
        "RAMP_DRAFT_DIR": str(temporary / "drafts"),
    }
    launch = "env -u RONNA_IDENTITY_TOKEN -u RONNA_CONTROL_TOKEN -u RONNA_CONTROL_URL -u EXO_CONFIG " + " ".join(shlex.quote(key + "=" + value) for key, value in runtime_env.items()) + " " + shlex.quote(shutil.which("ramp")) + " sessions"
    try:
        tmux("new-session", "-d", "-s", "starter", "-x", "150", "-y", "60", launch)
        time.sleep(0.8)
        command("starter-probe")
        wait_for("PLUGIN COMPOSED")
        tmux("send-keys", "-t", "starter", "C-y")
        wait_for("PERSONAL OVERRIDE")
        command("config-check")
        current = wait_for("Config check")
        assert "State" in current and "loaded" in current, current
        assert "ronna/plugin/ronna.lua ran" in current, current
        assert "failed" not in current.lower() and "disabled" not in current.lower(), current
        tmux("send-keys", "-t", "starter", "Escape")
        command("reload-config")
        wait_for("Reloaded ")
        command("starter-probe")
        wait_for("PLUGIN COMPOSED")
        tmux("send-keys", "-t", "starter", "C-y")
        wait_for("PERSONAL OVERRIDE")
    finally:
        subprocess.run(["tmux", "-L", session, "kill-server"], capture_output=True)

print("Passed: fresh Git installation, repeat install, pinned updates, personal-file preservation, dirty-checkout protection, plugin composition, personal keymaps, and installed Ramp reload")
