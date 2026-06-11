set shell := ["sh", "-ce"]
set positional-arguments := true


# Configuration.

cont_base_image_tag := "acont"
cont_base_image_title := "acont"
cont_base_image_desc := "acont"
cont_image_source := "https://github.com/im-0/acont"

[default]
[doc("List available recipes")]
list:
    @just --list

[doc("Build image")]
image-build:
    CONT_ARCH="$( uname --machine | sed "s,^aarch64$,arm64,g;s,^x86_64$,amd64,g" )"; \
    CONT_BRANCH="$( git rev-parse --abbrev-ref HEAD )"; \
    CONT_DATE="$( git log -1 --format=%cd --date=format:%Y-%m-%d -- . )"; \
    CONT_MANIFEST="{{ cont_base_image_tag }}:${CONT_BRANCH}-${CONT_DATE}"; \
    buildah inspect \
            --format "{{{{ .ImageCreatedBy }}" \
            "${CONT_MANIFEST}.${CONT_ARCH}" \
        || buildah build \
            --isolation "chroot" \
            --platform "${CONT_ARCH}" \
            --tag "${CONT_MANIFEST}.${CONT_ARCH}" \
            --annotation "org.opencontainers.image.title={{ cont_base_image_title }}" \
            --annotation "org.opencontainers.image.description={{ cont_base_image_desc }}" \
            --annotation "org.opencontainers.image.source={{ cont_image_source }}" \
            "."

[doc("Run image")]
run project_path name="":
    CONT_ARCH="$( uname --machine | sed "s,^aarch64$,arm64,g;s,^x86_64$,amd64,g" )"; \
    CONT_BRANCH="$( git rev-parse --abbrev-ref HEAD )"; \
    CONT_DATE="$( git log -1 --format=%cd --date=format:%Y-%m-%d -- . )"; \
    CONT_MANIFEST="{{ cont_base_image_tag }}:${CONT_BRANCH}-${CONT_DATE}"; \
    PROJECT_PATH="$( readlink --canonicalize "{{ project_path }}" )"; \
    if [ -n "{{ name }}" ]; then \
        CONT_NAME="{{ name }}"; \
    else \
        CONT_NAME="acont-$( basename "${PROJECT_PATH}" )"; \
    fi; \
    podman \
            run \
            --detach \
            --volume "${PROJECT_PATH}:/workspaces/project:Z" \
            --device "/dev/fuse" \
            --publish "127.0.0.1::22/tcp" \
            --publish "127.0.0.1::80/tcp" \
            --publish "127.0.0.1::443/tcp" \
            --publish "127.0.0.1::4096/tcp" \
            --publish "127.0.0.1::8008/tcp" \
            --publish "127.0.0.1::8080/tcp" \
            --publish "127.0.0.1::8443/tcp" \
            --env "TERM" \
            --env "COLORTERM" \
            --env "LS_COLORS" \
            --env "EDITOR" \
            --env "MERGE" \
            --env "PAGER" \
            --env "BAT_PAGER" \
            --env "BAT_STYLE" \
            --env "BAT_PAGING" \
            --env "BUILDAH_LAYERS" \
            --env "RUSTFLAGS" \
            --env "RUST_LOG" \
            --env "RUST_LIB_BACKTRACE" \
            --env "RUST_BACKTRACE" \
            --name "${CONT_NAME}" \
            "${CONT_MANIFEST}.${CONT_ARCH}" \
            /usr/bin/sshd -De; \
    if [ -e ~/.ssh/id_rsa.pub ]; then \
        podman exec "${CONT_NAME}" mkdir --parents "/root/.ssh"; \
        podman cp ~/.ssh/id_rsa.pub "${CONT_NAME}:/root/.ssh/authorized_keys"; \
        podman exec "${CONT_NAME}" chmod 0700 "/root/.ssh"; \
        podman exec "${CONT_NAME}" chmod 0600 "/root/.ssh/authorized_keys"; \
    fi; \
    podman port "${CONT_NAME}"

[doc("Shell inside running container")]
shell container_name:
    if [ -e ~/.pi/agent/auth.json ]; then \
        podman exec "{{ container_name }}" mkdir --parents "/root/.pi/agent"; \
        podman cp ~/.pi/agent/auth.json "{{ container_name }}:/root/.pi/agent/auth.json"; \
    fi
    if [ -e ~/.codex/auth.json ]; then \
        podman exec "{{ container_name }}" mkdir --parents "/root/.codex"; \
        podman cp ~/.codex/auth.json "{{ container_name }}:/root/.codex/auth.json"; \
    fi
    podman \
        exec \
        --interactive \
        --tty \
        --workdir "/workspaces/project" \
        --env "TERM" \
        --env "COLORTERM" \
        --env "LS_COLORS" \
        --env "EDITOR" \
        --env "MERGE" \
        --env "PAGER" \
        --env "BAT_PAGER" \
        --env "BAT_STYLE" \
        --env "BAT_PAGING" \
        --env "BUILDAH_LAYERS" \
        --env "RUSTFLAGS" \
        --env "RUST_LOG" \
        --env "RUST_LIB_BACKTRACE" \
        --env "RUST_BACKTRACE" \
        "{{ container_name }}" \
        bash --login
