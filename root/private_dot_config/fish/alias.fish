# Git
abbr -a g   git 
abbr -a gs  git status -sb
abbr -a ga  git add
abbr -a gc  git commit
abbr -a gcm git commit -m
abbr -a gca git commit --amend
abbr -a gcl git clone
abbr -a gco git checkout
abbr -a gp  git push
abbr -a gpf git push --force-with-lease
abbr -a gpl git pull
abbr -a gl  git l
abbr -a gd  git diff
abbr -a gds git diff --staged
abbr -a gr  git rebase -i HEAD~15
abbr -a gf  git fetch
abbr -a gfc git findcommit
abbr -a gfm git findmessage
abbr -a gco git checkout

# Node/NPM
abbr -a n   npm
abbr -a ni  npm install
abbr -a nr  npm remove
abbr -a nrb npm run build
abbr -a nrd npm run dev
abbr -a nrw npm run watch
abbr -a nrs npm run start
abbr -a nv  npm version

# ls
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
alias ls=lsd

# Misc
alias reload='exec fish'