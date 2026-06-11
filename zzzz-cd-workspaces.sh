if [ "${PWD}" == "/" ]; then
    cd /workspaces/* >/dev/null 2>&1 || cd ~
fi
