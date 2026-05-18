#
# This shell prompt config file was created by promptline.vim
#
function __promptline_host {
	if [[ -n "${SSH_CLIENT}" ]]; then
		printf "%s" "\\u@\\h"
	fi
}

function __promptline_last_exit_code {

	[[ $last_exit_code -gt 0 ]] || return 1;

	printf "%s" "$last_exit_code"
}
function __promptline_ps1 {
	local slice_prefix slice_empty_prefix slice_joiner slice_suffix is_prompt_empty=1

	# section "a" header
	slice_prefix="${a_bg}${sep}${a_fg}${a_bg}${space}" slice_suffix="$space${a_sep_fg}" slice_joiner="${a_fg}${a_bg}${alt_sep}${space}" slice_empty_prefix="${a_fg}${a_bg}${space}"
	[ $is_prompt_empty -eq 1 ] && slice_prefix="$slice_empty_prefix"
	# section "a" slices
	__promptline_wrapper "\t" "$slice_prefix" "$slice_suffix" && { slice_prefix="$slice_joiner"; is_prompt_empty=0; }

	# section "warn" header
	slice_prefix="${warn_bg}${sep}${warn_fg}${warn_bg}${space}" slice_suffix="$space${warn_sep_fg}" slice_joiner="${warn_fg}${warn_bg}${alt_sep}${space}" slice_empty_prefix="${warn_fg}${warn_bg}${space}"
	[ $is_prompt_empty -eq 1 ] && slice_prefix="$slice_empty_prefix"
	# section "warn" slices
	__promptline_wrapper "$(__promptline_last_exit_code)" "$slice_prefix" "$slice_suffix" && { slice_prefix="$slice_joiner"; is_prompt_empty=0; }

	# section "b" header
	slice_prefix="${b_bg}${sep}${b_fg}${b_bg}${space}" slice_suffix="$space${b_sep_fg}" slice_joiner="${b_fg}${b_bg}${alt_sep}${space}" slice_empty_prefix="${b_fg}${b_bg}${space}"
	[ $is_prompt_empty -eq 1 ] && slice_prefix="$slice_empty_prefix"
	# section "b" slices
	__promptline_wrapper "$(__promptline_host)" "$slice_prefix" "$slice_suffix" && { slice_prefix="$slice_joiner"; is_prompt_empty=0; }

	# section "c" header
	[ $is_prompt_empty -eq 1 ] && slice_prefix="$slice_empty_prefix"
	# section "c" slices
	__promptline_vcs && { slice_prefix="$slice_joiner"; is_prompt_empty=0; }

	# section "x" header
	slice_prefix="${x_bg}${sep}${x_fg}${x_bg}${space}" slice_suffix="$space${x_sep_fg}" slice_joiner="${x_fg}${x_bg}${alt_sep}${space}" slice_empty_prefix="${x_fg}${x_bg}${space}"
	[ $is_prompt_empty -eq 1 ] && slice_prefix="$slice_empty_prefix"
	# section "x" slices
	__promptline_wrapper "$(__promptline_cwd)" "$slice_prefix" "$slice_suffix" && { slice_prefix="$slice_joiner"; is_prompt_empty=0; }

	# section "y" header
	slice_prefix="${y_bg}${sep}${y_fg}${y_bg}${space}" slice_suffix="$space${y_sep_fg}" slice_joiner="${y_fg}${y_bg}${alt_sep}${space}" slice_empty_prefix="${y_fg}${y_bg}${space}"
	[ $is_prompt_empty -eq 1 ] && slice_prefix="$slice_empty_prefix"
	# section "y" slices
	__promptline_wrapper "${VIRTUAL_ENV##*/}" "$slice_prefix" "$slice_suffix" && { slice_prefix="$slice_joiner"; is_prompt_empty=0; }

	# close sections
	printf "%s" "${reset_bg}${sep}$reset$space"
}
function __promptline_vcs {
	slice_prefix="${c_bg}${sep}${c_fg}${c_bg}${space}" slice_suffix="$space${c_sep_fg}" slice_joiner="${c_fg}${c_bg}${alt_sep}${space}" slice_empty_prefix="${c_fg}${c_bg}${space}"
	local branch
	local branch_symbol=" "
	local added_symbol="${green_fg}${c_mod_bg}+"
	local unmerged_symbol="${red_fg}${c_mod_bg}✗"
	local modified_symbol="${blue_fg}${c_mod_bg}✹"
	local clean_symbol="${green_fg}${c_bg}✔"
	local has_untracked_files_symbol="${red_fg}${c_mod_bg}✭"

	local ahead_symbol="↑"
	local behind_symbol="↓"

	local unmerged_count=0 modified_count=0 has_untracked_files=0 added_count=0 is_clean=""

	# git
	if hash git 2>/dev/null; then
		if branch=$( { git symbolic-ref --quiet HEAD || git rev-parse --short HEAD; } 2>/dev/null ); then
			branch=${branch##*/}
			if [[ $(git rev-parse --is-inside-work-tree 2>/dev/null) == true ]]; then
				set -- $(git rev-list --left-right --count @{upstream}...HEAD 2>/dev/null)
				local behind_count=$1
				local ahead_count=$2

				# Added (A), Copied (C), Deleted (D), Modified (M), Renamed (R), changed (T), Unmerged (U), Unknown (X), Broken (B)
				while read line; do
					case "$line" in
						M*) modified_count=$(( $modified_count + 1 )) ;;
						U*) unmerged_count=$(( $unmerged_count + 1 )) ;;
					esac
				done < <(git diff --name-status)

				while read line; do
					case "$line" in
						*) added_count=$(( $added_count + 1 )) ;;
					esac
				done < <(git diff --name-status --cached)

				if [ -n "$(git ls-files --others --exclude-standard)" ]; then
					has_untracked_files=1
				fi

				if [ $(( unmerged_count + modified_count + has_untracked_files + added_count )) -eq 0 ]; then
					is_clean=1
					slice_prefix="${c_bg}${sep}${c_fg}${c_bg}${space}" slice_suffix="$space${c_sep_fg}" slice_joiner="${c_fg}${c_bg}${alt_sep}${space}" slice_empty_prefix="${c_fg}${c_bg}${space}"
				else
					slice_prefix="${c_mod_bg}${sep}${c_fg}${c_mod_bg}${space}" slice_suffix="$space${c_mod_sep_fg}" slice_joiner="${c_fg}${c_mod_bg}${alt_sep}${space}" slice_empty_prefix="${c_fg}${c_mod_bg}${space}"
				fi

				local leading_whitespace=" "
		 		printf "%s" "${slice_prefix}${branch_symbol}${branch:-unknown}"
				[[ $ahead_count -gt 0 ]]         && { printf "%s" "$leading_whitespace$ahead_symbol"; leading_whitespace=" "; }
				[[ $behind_count -gt 0 ]]        && { printf "%s" "$leading_whitespace$behind_symbol"; leading_whitespace=" "; }
				[[ $modified_count -gt 0 ]]      && { printf "%s" "$leading_whitespace$modified_symbol"; leading_whitespace=" "; }
				[[ $unmerged_count -gt 0 ]]      && { printf "%s" "$leading_whitespace$unmerged_symbol"; leading_whitespace=" "; }
				[[ $added_count -gt 0 ]]         && { printf "%s" "$leading_whitespace$added_symbol"; leading_whitespace=" "; }
				[[ $has_untracked_files -gt 0 ]] && { printf "%s" "$leading_whitespace$has_untracked_files_symbol"; leading_whitespace=" "; }
				[[ $is_clean -gt 0 ]]            && { printf "%s" "$leading_whitespace$clean_symbol"; leading_whitespace=" "; }
				printf "%s" "${slice_suffix}"
				return
			else
		 		printf "%s" "${slice_prefix}${branch_symbol}${branch:-unknown}${slice_suffix}"
				return
			fi
		fi
	fi
	return 1
}
function __promptline_cwd {
	# get first char of the path, i.e. tilde or slash
	local cwd="$(dirs)"

	printf "%s" "$cwd"
}
function __promptline_wrapper {
	# wrap the text in $1 with $2 and $3, only if $1 is not empty
	# $2 and $3 typically contain non-content-text, like color escape codes and separators

	[[ -n "$1" ]] || return 1
	printf "%s" "${2}${1}${3}"
}
function __promptline {
	local last_exit_code="${PROMPTLINE_LAST_EXIT_CODE:-$?}"

	local esc=$'[' end_esc=m
	local noprint='\[' end_noprint='\]'

	local wrap="$noprint$esc" end_wrap="$end_esc$end_noprint"
	local space=" "
	local sep=""
	local rsep=""
	local alt_sep=""
	local alt_rsep=""
	local reset="${wrap}0${end_wrap}"
	local reset_bg="${wrap}49${end_wrap}"
	local a_fg="${wrap}0;38;5;16${end_wrap}"
	local a_bg="${wrap}48;5;7${end_wrap}"
	local a_sep_fg="${wrap}0;38;5;7${end_wrap}"
	local b_fg="${wrap}0;38;5;7${end_wrap}"
	local b_bg="${wrap}48;5;16${end_wrap}"
	local b_sep_fg="${wrap}0;38;5;16${end_wrap}"
	local c_fg="${wrap}0;38;5;16${end_wrap}"
	local c_bg="${wrap}48;5;7${end_wrap}"
	local c_mod_bg="${wrap}48;5;3${end_wrap}"
	local c_sep_fg="${wrap}0;38;5;7${end_wrap}"
	local c_mod_sep_fg="${wrap}0;38;5;3${end_wrap}"
	local warn_fg="${wrap}0;38;5;7${end_wrap}"
	local warn_bg="${wrap}48;5;160${end_wrap}"
	local warn_sep_fg="${wrap}0;38;5;160${end_wrap}"
	local x_fg="${wrap}0;38;5;16${end_wrap}"
	local x_bg="${wrap}48;5;4${end_wrap}"
	local x_sep_fg="${wrap}0;38;5;4${end_wrap}"
	local y_fg="${wrap}0;38;5;250${end_wrap}"
	local y_bg="${wrap}48;5;236${end_wrap}"
	local y_sep_fg="${wrap}0;38;5;236${end_wrap}"
	local red_fg="${wrap}0;38;5;9${end_wrap}"
	local bold_red_fg="${wrap}1;38;5;9${end_wrap}"
	local green_fg="${wrap}0;38;5;10${end_wrap}"
	local bold_green_fg="${wrap}1;38;5;10${end_wrap}"
	local blue_fg="${wrap}0;38;5;4${end_wrap}"
	local bold_blue_fg="${wrap}1;38;5;4${end_wrap}"

	if [[ $EUID -eq 0 ]]; then
		local shell_sign="${bold_red_fg}\n# ${reset}"
	else
		local shell_sign="${bold_green_fg}\n$ ${reset}"
	fi

	PS1="\n$(__promptline_ps1)${shell_sign}"
}

if [[ ! "$PROMPT_COMMAND" == *__promptline* ]]; then
	PROMPT_COMMAND='__promptline;'$'\n'"$PROMPT_COMMAND"
fi
