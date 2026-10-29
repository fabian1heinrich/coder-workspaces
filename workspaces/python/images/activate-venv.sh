# Image-owned shell default; persistent dotfiles cannot hide this file.
# The environment is created by workspace-startup before the agent starts.
if [ -r /home/coder/.venv/bin/activate ]; then
    if [ -n "${ZSH_VERSION:-}" ]; then
        # The global zshrc runs before the user's zshrc. Activate at the first
        # prompt so user PATH/theme setup cannot undo the initial activation.
        _coder_activate_venv() {
            add-zsh-hook -d precmd _coder_activate_venv
            . /home/coder/.venv/bin/activate
            unfunction _coder_activate_venv
        }
        autoload -Uz add-zsh-hook
        add-zsh-hook precmd _coder_activate_venv
    else
        . /home/coder/.venv/bin/activate
    fi
fi
