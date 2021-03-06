#!/bin/bash

shopt -s extglob

BASE_DIR=$(pwd)
SCM="git svn hg bzr cvs"
CMD=

function cmd_exists
{
	local cmd=

	for cmd in $CMD; do
		[ "$1" = "$cmd" ] && return 0
	done

	return 1
}

function get_absolute_path
{
	pushd "$1" > /dev/null
	pwd
	popd > /dev/null
}

function get_relative_path
{
	echo ${1/#${BASE_DIR}*(\/)/}
}

function has_repos
{
	[ -d "$1" -a "$1" != "${1/%repos-*([^\/])/}" ]
}

function get_git_branch_name
{
	git symbolic-ref -q --short HEAD
}

function update_repo
{
	local repo_abs_path="$1"
	local repo_rel_path=$(get_relative_path "$repo_abs_path")
	local scm=

	pushd "$repo_abs_path" > /dev/null

	for scm in $SCM; do
		if [ -d ".${scm}" -o \( "$scm" = "cvs" -a -d "CVS" \) ]; then
			echo "${scm} ${repo_rel_path} ..."

			if cmd_exists "$scm"; then
				case "$scm" in
					'git')
						git fetch --all --prune
						git merge --ff-only "origin/$(get_git_branch_name)"
						if [ -e ".gitmodules" ]; then
							git submodule update --init --recursive
						fi
						;;
					'svn')
						svn update
						;;
					'hg')
						hg pull -u
						;;
					'bzr')
						bzr update
						;;
					'cvs')
						cvs update
						;;
				esac
			else
				echo "skipped"
			fi

			break
		fi
	done

	popd > /dev/null
}

function clean_repo
{
	local repo_abs_path="$1"
	local repo_rel_path=$(get_relative_path "$repo_abs_path")
	local scm=

	pushd "$repo_abs_path" > /dev/null

	for scm in $SCM; do
		if [ -d ".${scm}" -o \( "$scm" = "cvs" -a -d "CVS" \) ]; then
			if cmd_exists "$scm"; then
				case "$scm" in
					'git')
						printf "%-3s gc %s\n" "$scm" "$repo_rel_path"
						git gc
						;;
					'svn')
						if svn status --depth empty | grep L &> /dev/null; then
							printf "%-3s cleanup %s\n" "$scm" "$repo_rel_path"
							svn cleanup
						fi
						;;
					'hg')
						;;
					'bzr')
						;;
					'cvs')
						;;
				esac
			fi

			break
		fi
	done

	popd > /dev/null
}

function show_repo_url
{
	local repo_abs_path="$1"
	local repo_rel_path=$(get_relative_path "$repo_abs_path")
	local scm=

	pushd "$repo_abs_path" > /dev/null

	for scm in $SCM; do
		if [ -d ".${scm}" -o \( "$scm" = "cvs" -a -d "CVS" \) ]; then
			local url=

			if cmd_exists "$scm"; then
				case "$scm" in
					'git')
						url=$(git config remote.origin.url)
						;;
					'svn')
						url=$(svn info | awk '/^URL: / { print $2 }')
						;;
					'hg')
						url=$(hg showconfig paths.default)
						;;
					'bzr')
						url=$(bzr config bound_location)
						;;
					'cvs')
						url=$(cat CVS/Root)
						;;
				esac
			else
				url="---"
			fi

			[ ! -z "$url" ] && printf "%-3s %s %s\n" "$scm" "$repo_rel_path" "$url"
			break
		fi
	done

	popd > /dev/null
}

function show_repo_path
{
	local repo_abs_path="$1"
	echo $(get_relative_path "$repo_abs_path")
}

function show_repo_name
{
	local repo_abs_path="$1"
	echo $(basename "$repo_abs_path")
}

function repo_action
{
	local action=$1
	local curr_abs_dir="$2"

	pushd "$curr_abs_dir" > /dev/null

	local file=
	for file in `ls`; do
		[ ! -d "$file" ] && continue

		local repo_abs_dir="${curr_abs_dir}/${file}"

		if has_repos "$repo_abs_dir"; then
			repo_action $action "$repo_abs_dir"
		else
			$action "$repo_abs_dir"
		fi
	done

	popd > /dev/null
}

for scm in $SCM; do
	type -p "$scm" &> /dev/null && CMD="$scm $CMD"
done

ACTION=
case "$1" in
	'update')
		ACTION=update_repo
		;;
	'clean')
		ACTION=clean_repo
		;;
	'urls')
		ACTION=show_repo_url
		;;
	'paths')
		ACTION=show_repo_path
		;;
	'names')
		ACTION=show_repo_name
		;;
	*)
		echo "Invalid action: $1"
		exit 1
		;;
esac

DIR="$2"
if [ ! -z "$DIR" -a ! -d "$DIR" ]; then
	echo "Invalid directory: $DIR"
	exit 1
elif [ -z "$DIR" ]; then
	DIR=$(pwd)
fi

repo_action $ACTION $(get_absolute_path "$DIR")
