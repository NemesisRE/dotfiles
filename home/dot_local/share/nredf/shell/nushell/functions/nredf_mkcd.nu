# chezmoi-managed nu function file.
#
# mkdir -p the given directory and cd into it in one step. `--env` is
# required for `cd` to actually change the caller's directory — see
# docs/shells.md's "Nu's `def` is not dynamically scoped" note.

def --env mkcd [dir: string] {
    mkdir $dir
    cd $dir
}
