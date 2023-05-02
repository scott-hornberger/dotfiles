alias aurora-tunnel="ssh -D 8127 -f -C -q -N cluster-admin01-phx2"
alias todo="subl ~/temp/Markdown-docs/scratch.md"
alias unsstats="$go/bazel-bin/src/code.uber.internal/infra/uns/net/discovery/bin/unsstats/unsstats_/unsstats"

#count blacklist services
blacklistCount () {oc read compute-balancer production blacklist | grep "^[^=]" | grep name | wc -l;}

# list adhoc machine
clusteradm () { lzc host list -n "cluster-admin*-"$1"*" --format="{{.Hostname}}"; }

getrg() { grep --color=always -rn -B 7 -A 20 $infcon/net/traffic -e $1; }

mono=~/go-code
export WEB_CODE=~/web-code
export UP_FRONT=$WEB_CODE/src/infra/scd/up/up-front
upf=$UP_FRONT
alias cdupf="cd $UP_FRONT"

alias mono="cd $mono"
gocode=~/gocode
alias gocode="cd $gocode"
infcon=$gocode/src/code.uber.internal/infra/config
alias infcon="cd $infcon"
objcon=$gocode/src/code.uber.internal/infra/objectconfig
alias objcon="cd $objcon"

bbuild() {
	bazel build //$1
}

btest() {
	bazel test //$1:go_default_test
}

co=src/code.uber.internal/infra/coconut
web=$co/coconut-web

function sayr() {
	if [[ $1 -eq 0 ]]; then say pass; else say fail; fi
}
alias sayres="sayr $?"

function arc() {
  if [ "$1" = "diff" ]; then
    command arc diff --noautoland --nointeractive --amend-all --add-all --apply-patches --use-commit-message HEAD --message update  "${@:2}"
  else
    command arc "$@"
  fi
}
