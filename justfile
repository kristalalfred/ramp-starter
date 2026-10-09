default: check

check:
    shellcheck install.sh
    python3 scripts/check.py

install:
    sh install.sh

update:
    sh install.sh --update

run:
    RAMP_CONFIG="$PWD/init.lua" ramp sessions
