#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function grep_invalid_utf8() {
	perl -l -ne '/^([\000-\177]|[\300-\337][\200-\277]|[\340-\357][\200-\277]{2}|[\360-\367][\200-\277]{3}|[\370-\373][\200-\277]{4}|[\374-\375][\200-\277]{5})*$/ or print'
}

function fix_invalid_utf8() {
  if command -pv rename &>/dev/null; then
    echo "command rename not found"
    return 1
  fi
	find . | grep_invalid_utf8 | rename 'BEGIN {binmode STDIN, ":encoding(latin1)"; use Encode;}$_=encode("utf8", $_)'
}
