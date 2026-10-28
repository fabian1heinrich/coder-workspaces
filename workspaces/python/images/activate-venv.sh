# Image-owned shell default; persistent dotfiles cannot hide this file.
# The environment is created by workspace-startup before the agent starts.
if [ -n "${CODER_PYTHON_ENVIRONMENT:-}" ] &&
   [ -r "$CODER_PYTHON_ENVIRONMENT/bin/activate" ]; then
    . "$CODER_PYTHON_ENVIRONMENT/bin/activate"
fi
