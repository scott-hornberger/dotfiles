fzf-git-branch() {
    git rev-parse HEAD > /dev/null 2>&1 || return

    git branch --color=always --all --sort=-committerdate |
        grep -v HEAD |
        fzf --height 50% --ansi --no-multi --preview-window right:75% \
            --preview 'git log -n 50 --color=always --date=short --pretty="format:%C(auto)%cd %h%d %s" $(sed "s/.* //" <<< {})' |
        sed "s/.* //"
}

fzf-git-checkout() {
    git rev-parse HEAD > /dev/null 2>&1 || return

    local branch

    branch=$(fzf-git-branch)
    if [[ "$branch" = "" ]]; then
        echo "No branch selected."
        return
    fi

    # If branch name starts with 'remotes/' then it is a remote branch. By
    # using --track and a remote branch name, it is the same as:
    # git checkout -b branchName --track origin/branchName
    if [[ "$branch" = 'remotes/'* ]]; then
        git checkout --track $branch
    else
        git checkout $branch;
    fi
}

git-fshow() {
        local g=(
                git log
                --graph
                --format='%C(auto)%h%d %s %C(white)%C(bold)%cr'
                --color=always
                "$@"
        )

        local fzf=(
                fzf
                --ansi
                --reverse
                --tiebreak=index
                --no-sort
                --bind=ctrl-s:toggle-sort
                --preview 'f() { set -- $(echo -- "$@" | grep -o "[a-f0-9]\{10\}"); [ $# -eq 0 ] || git show --color=always $1; }; f {}'
        )
        $g | $fzf
}


alias glog='git-fshow'
alias gb='fzf-git-branch'
alias gco='fzf-git-checkout'
