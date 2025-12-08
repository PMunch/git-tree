# git-tree
This is a small shell script which adds a git-aware
[`tree`](https://gitlab.com/OldManProgrammer/unix-tree) command. The `tree`
command by default is very useful to visualize a folder hierarchy, but I found
myself bouncing between `git status` and `tree` to get a good overview of what
the actual status was of my repo. This small bash script combines the two
commands into `git tree` which shows the normal output of `tree`, but enchanced
by `git status`. The way it works is by calling `git status --porcelain` to
grab the Git status in a machine-readable format, then creating a .info file
for tree to use to add comments to its output. The output of tree is then
parsed to bring these comments inline and convert some of them into just
coloration. The result of this transformation is that:

- .gitignore is used to ignore files (this is an option passed to tree)
- Untracked files are greyed out (SGR 2)
- Modifications have a keyword behind it in yellow (SGR 33), keywords are "modified", "file type changed", "renamed", "copied", and "updated"
- New files have the keyword "added" behind them in green (SGR 32)
- Deleted files have the keyword "deleted" behind them in red (SGR 31)
- Staged files have the above plus the keyword "staged" in green (SGR 32)
- Moved files show the keywords on the new file with a "was <old filename>" appended

To make deleted files show up in the output simple dummy files are `touch`-ed
into the directory and deleted after the tree is created. This is only done
after checking that there is nothing there already.

This is at the moment just a quick script I threw together, it doesn't handle
all scenarios of git output, and could easily be improved.
