#!/bin/bash

# Courtesy of @jmc
#
# The token authentication mechanism that affords us access to other private
# repositories requires that we use HTTPS URLs for GitHub, rather than SSH.
#
# Create a git(1) wrapper program.  This program will attempt to convert
# any SSH URLs found in the arguments to HTTPS URLs and then exec the real git.
#
mkdir -p /work/workaround
cat >/work/workaround/git <<'EOF'
#!/bin/bash
args=()
while (( $# > 0 )); do
	val="$1"
	val="${val//ssh:\/\/git@/https:\/\/}"
	val="${val//git@github.com:/https:\/\/github.com\/}"
	if [[ "$val" != "$1" ]]; then
		printf 'REGRET: transformed "%s" -> "%s"\n' "$1" "$val" >&2
	fi
	args+=( "$val" )
	shift
done
#
# Remove the workaround directory from PATH before executing the real git:
#
export PATH=${PATH/#\/work\/workaround:/}
exec /usr/bin/git "${args[@]}"
EOF
chmod +x /work/workaround/git
export PATH="/work/workaround:$PATH"

#
# Finally, require that cargo use the git CLI -- or, rather, our wrapper! --
# instead of the built-in support.  This achieves two things: first, SSH URLs
# should be transformed on fetch without requiring Cargo.toml rewriting, which
# is especially difficult in transitive dependencies; second, Cargo does not
# seem willing on its own to look in ~/.netrc and find the temporary token that
# buildomat generates for our job, so we must use git which uses curl.
#
export CARGO_NET_GIT_FETCH_WITH_CLI=true
