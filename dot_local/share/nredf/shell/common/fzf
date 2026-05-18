#     ____      ____
#    / __/___  / __/
#   / /_/_  / / /_
#  / __/ / /_/ __/
# /_/   /___/_/-completion
#

_fzf_complete_ssh() {
  _fzf_complete '+m' "$@" < <(
    cat <(awk '{ print $1 " " $1 }' ~/.ssh/hosts 2>/dev/null) \
        <(grep -i '^host' ~/.ssh/config /etc/ssh/ssh_config 2>/dev/null | grep -v '\*' | awk '{for (i = 2; i <= NF; i++) print $1 " " $i}') \
        <(grep -oE '^[[a-z0-9.,:-]+' ~/.ssh/known_hosts 2>/dev/null | tr ',' '\n' | tr -d '[' | awk '{ print $1 " " $1 }') \
        <(grep -v '^\s*\(#\|$\)' /etc/hosts 2>/dev/null | grep -Fv '0.0.0.0') | awk '{if (length($2) > 0) {print $2}}' | sort -u)
}

_fzf_complete_scp() {
  _fzf_complete_ssh "@"
}

_fzf_complete_ping() {
  _fzf_complete_ssh "@"
}
