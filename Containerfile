ARG fedora_version=43

FROM registry.fedoraproject.org/fedora:${fedora_version}

ARG mingw_llvm_version="20260602"

ARG rust_toolchain_version="1.96.0"
ARG rust_toolchain_profile="default"
ARG rust_toolchain_components="rust-analyzer,rust-src"
ARG rust_toolchain_targets="wasm32-unknown-unknown x86_64-pc-windows-gnu aarch64-pc-windows-gnullvm"

ARG trunk_version="0.21.14"
ARG wasm_bindgen_version="0.2.123"
ARG wasm_opt_version="version_129"

COPY "zzzz-cd-workspaces.sh" "/etc/profile.d/zzzz-cd-workspaces.sh"
COPY "zzzz-fancy-prompt.sh" "/etc/profile.d/zzzz-fancy-prompt.sh"
COPY "gitconfig" "/root/.gitconfig"
RUN mkdir --parents "/root/.config/htop"
COPY "htoprc" "/root/.config/htop/htoprc"
COPY "tmux.conf" "/etc/tmux.conf"
RUN mkdir "/workspaces"

COPY "is_amd64" "/usr/local/bin/is_amd64"
COPY "is_aarch64" "/usr/local/bin/is_aarch64"

# Make sure that man pages are installed. Needed only on newer Fedora releases.
RUN sed -i "s,^ *tsflags *= *nodocs *$,," /etc/dnf/dnf.conf

RUN dnf --refresh upgrade --assumeyes

# Quality of life packages.
RUN dnf \
        install \
        --assumeyes \
        "glibc-langpack-en" \
        "bash-completion" \
        "coreutils-common" \
        "man-db" \
        "man-pages" \
        "bat" \
        "fzf" \
        "ripgrep" \
        "plocate" \
        "procps-ng" \
        "psmisc" \
        "htop" \
        "btop" \
        "iputils" \
        "iproute" \
        "moreutils" \
        "pv" \
        "mc" \
        "wget" \
        "nmap-ncat" \
        "rsync" \
        "findutils" \
        "file" \
        "xz" \
        "xz-lzma-compat" \
        "zstd" \
        "unzip" \
        "p7zip" \
        "p7zip-plugins" \
        "sqlite" \
        "vim-enhanced" \
        "nano" \
        "bc" \
        "git" \
        "gh" \
        "diffutils" \
        "patch" \
        "tmux" \
        "strace" \
        "lsof" \
        "usbutils" \
        "openssl"

RUN dnf \
        install \
        --assumeyes \
        "clang" \
        "gcc" \
        "gcc-c++" \
        "mold" \
        "lld" \
        "gdb" \
        "rust-gdb" \
        "lldb" \
        "rust-lldb" \
        "just" \
        "cmake"

# llvm-mingw
RUN if is_amd64; then \
    dnf \
        install \
        --assumeyes \
        "mingw64-gcc" \
        "mingw64-gcc-c++"; \
    fi

RUN if is_aarch64; then \
    git \
        clone \
        --branch "${mingw_llvm_version}" \
        --depth 1 \
        "https://github.com/mstorsjo/llvm-mingw" \
        "/root/llvm-mingw"; \
    fi
RUN if is_aarch64; then \
    cd "/root/llvm-mingw" \
    && TOOLCHAIN_ARCHS="aarch64" ./build-all.sh \
        --disable-lldb \
        --disable-lldb-mi \
        --disable-clang-tools-extra \
        "/opt/aarch64-w64-mingw32"; \
    fi
RUN if is_aarch64; then \
    rm -rf "/root/llvm-mingw"; \
    fi
ENV PATH="/opt/aarch64-w64-mingw32/bin:${PATH}"

# Tools for generating docker/podman images.
RUN dnf \
        install \
        --assumeyes \
        "buildah" \
        "skopeo"

# Install Rust toolchain.
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- \
        -y \
        --default-toolchain "${rust_toolchain_version}" \
        --profile "${rust_toolchain_profile}" \
        --component "${rust_toolchain_components}" \
        --no-update-default-toolchain \
        --no-modify-path
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup \
        target add \
        --toolchain "${rust_toolchain_version}" \
        ${rust_toolchain_targets}

RUN rustup completions "bash" >/etc/bash_completion.d/rustup
RUN rustup completions "bash" "cargo" >/etc/bash_completion.d/cargo

# Install `cargo-docs-rs`.
RUN cargo \
        install \
        --bins \
        --all-features \
        "cargo-docs-rs"
RUN rustup \
        toolchain \
        install \
        --profile "${rust_toolchain_profile}" \
        --component "${rust_toolchain_components}" \
        "nightly"

# Install `trunk`.
RUN cargo \
        install \
        --bins \
        --locked \
        "trunk@${trunk_version}"
# Install `wasm-bindgen`.
RUN cargo \
        install \
        --bins \
        --locked \
        "wasm-bindgen-cli@${wasm_bindgen_version}"
# Build `wasm-opt`.
RUN dnf \
        install \
        --assumeyes \
        "cmake" \
        "lld"
RUN git \
        clone \
        --branch "${wasm_opt_version}" \
        --depth 1 \
        --recurse-submodules \
        --shallow-submodules \
        "https://github.com/WebAssembly/binaryen" \
        "/tmp/binaryen"
RUN mkdir "/tmp/binaryen/build"
RUN cd "/tmp/binaryen/build" \
        && cmake \
            -D "CMAKE_C_COMPILER=clang" \
            -D "CMAKE_CXX_COMPILER=clang++" \
            -D "CMAKE_BUILD_TYPE=Release" \
            -D "BUILD_STATIC_LIB=ON" \
            ..
RUN cd "/tmp/binaryen/build" \
        && make "wasm-opt"
RUN strip "/tmp/binaryen/build/bin/wasm-opt"

ENV TRUNK_SKIP_VERSION_CHECK="true"
ENV TRUNK_TOOLS_WASM_BINDGEN="${wasm_bindgen_version}"
ENV TRUNK_TOOLS_WASM_OPT="${wasm_opt_version}"
ENV TRUNK_SERVE_ADDRESS="0.0.0.0"

# Install `uv`
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
# Install `ruff`
RUN curl -LsSf https://astral.sh/ruff/install.sh | sh

# Install `cargo shear`
RUN cargo \
        install \
        --bins \
        --locked \
        "cargo-shear"

# Remove caches.
RUN dnf clean all
RUN rm -rf "/root/.cargo/registry"
RUN rm -rf "/root/.cache"
RUN rm -f /var/log/dnf5.log*

# Install `wasm-opt` into location expected by `trunk`.
RUN mkdir --parents "/root/.cache/trunk/wasm-opt-${wasm_opt_version}/bin"
RUN mv \
        "/tmp/binaryen/build/bin/wasm-opt" \
        "/root/.cache/trunk/wasm-opt-${wasm_opt_version}/bin/wasm-opt"
RUN rm -rf "/tmp/binaryen"

RUN rm "/usr/local/bin/is_amd64"
RUN rm "/usr/local/bin/is_aarch64"

RUN mandb --create
RUN updatedb

ENV LANG="en_US.UTF-8"
CMD ["/bin/bash", "--login"]
