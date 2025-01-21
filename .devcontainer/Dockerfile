FROM ubuntu:latest

# Install 'en_US.UTF-8' locales
RUN apt-get update && \
    apt-get install -y locales && \
    rm -rf /var/lib/apt/lists/* && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# Set Locale and Python Modifiers
ENV LANG en_US.utf8
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Update the system and install necessary tools
RUN apt-get update && \
    apt install --yes --no-install-recommends \
    bzip2 \
    ca-certificates \
    curl \
    git \
    groff \
    less \
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

# Install Micromamba
ENV MAMBA_ROOT_PREFIX /opt/conda
RUN curl -Ls https://micro.mamba.pm/api/micromamba/linux-aarch64/latest | tar -xvj -C /usr/ bin/micromamba && \
    mkdir -p $MAMBA_ROOT_PREFIX && \
    chown $VSCODE_USER:$VSCODE_USER $MAMBA_ROOT_PREFIX && \
    chmod a+rx $MAMBA_ROOT_PREFIX && \
    printf "channels:\n  - conda-forge\n" >> $MAMBA_ROOT_PREFIX/.mambarc

# Install OhMyZSH, Initialize Micromamba and Customize $VSCODE_USER environment
USER $VSCODE_USER
ENV WORKSPACE_PATH /workspace
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k && \
    sed -i '/^[^#]*ZSH_THEME/s/.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc && \
    micromamba shell init -s zsh && \
    echo 'alias project_manager="micromamba run python $WORKSPACE_PATH/.devcontainer/scripts/project_manager.py"' >> ~/.zshrc && \
    echo 'alias pm="project_manager"' >> ~/.zshrc && \
    echo 'alias mm="micromamba"' >> ~/.zshrc && \
    echo 'source ~/.p10k.zsh' >> ~/.zshrc && \
    echo 'micromamba activate' >> ~/.zshrc
