FROM ubuntu:24.04

# Install 'en_US.UTF-8' locales
RUN apt-get update && \
    apt-get install -y locales && \
    rm -rf /var/lib/apt/lists/* && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# Set Locale and Python Modifiers
ENV LANG en_US.utf8
ENV LC_ALL en_US.UTF-8
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV CODING_LANGUAGE python
ENV CARGO_HOME /opt/cargo
ENV RUSTUP_HOME /opt/rustup
ENV RUSTUP_INIT_SKIP_TERM_CHECK yes

# Update the system and install necessary tools
RUN apt-get update && \
    apt install --yes --no-install-recommends \
    build-essential \
    bzip2 \
    ca-certificates \
    clang \
    curl \
    git \
    jq \
    libbz2-dev \
    libssl-dev \
    openssh-client \
    pkg-config \
    sudo \
    universal-ctags \
    unzip \
    vim \
    zsh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add a non-root user with sudo privileges
ENV VSCODE_USER vscode
RUN useradd -m -s /bin/zsh $VSCODE_USER && \
    passwd -d $VSCODE_USER && \
    usermod -aG sudo $VSCODE_USER && \
    echo "$VSCODE_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$VSCODE_USER && \
    chmod 0440 /etc/sudoers.d/$VSCODE_USER && \
    chsh --shell /bin/zsh $VSCODE_USER

# Install Micromamba and Rust
ENV MAMBA_ROOT_PREFIX /opt/conda
RUN curl -Ls https://micro.mamba.pm/api/micromamba/linux-aarch64/2.0.5 | tar -xvj -C /usr/ bin/micromamba && \
    mkdir -p $MAMBA_ROOT_PREFIX && \
    chown -R $VSCODE_USER:$VSCODE_USER $MAMBA_ROOT_PREFIX && \
    chmod -R a+rx $MAMBA_ROOT_PREFIX && \
    chown $VSCODE_USER:$VSCODE_USER /usr/bin/micromamba && \
    printf "channels:\n  - conda-forge\nchannel_priority: strict\n" > $MAMBA_ROOT_PREFIX/.mambarc && \
    sh -c "$(curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs)" -s -y --quiet && \
    chown -R $VSCODE_USER:$VSCODE_USER $RUSTUP_HOME $CARGO_HOME

# Install OhMyZSH, Initialize Micromamba, Install toml2json, sccache, cargo-sort, cocogitto, Add Cargo to PATH and Customize $VSCODE_USER environment
USER $VSCODE_USER
ENV WORKSPACE_PATH /workspace
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k && \
    sed -i '/^[^#]*ZSH_THEME/s/.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc && \
    ${CARGO_HOME}/bin/cargo install toml2json && \
    ${CARGO_HOME}/bin/cargo install sccache && \
    ${CARGO_HOME}/bin/cargo install cargo-sort && \
    ${CARGO_HOME}/bin/cargo install cocogitto && \
    micromamba shell init -s zsh && \
    echo 'export PATH=$CARGO_HOME/bin:$PATH' >> ~/.zshrc && \
    echo 'export RUSTC_WRAPPER=$(which sccache)' >> ~/.zshrc && \
    echo 'alias project_manager="$WORKSPACE_PATH/.devcontainer/scripts/${CODING_LANGUAGE}/project_manager.sh"' >> ~/.zshrc && \
    echo 'alias pm="project_manager"' >> ~/.zshrc && \
    echo 'alias mm="micromamba"' >> ~/.zshrc && \
    echo 'source ~/.p10k.zsh' >> ~/.zshrc && \
    echo 'micromamba activate' >> ~/.zshrc
