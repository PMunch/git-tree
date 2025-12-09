#!/bin/bash
TREEPATH=${*: -1}
[ "$TREEPATH" = "$0" ] && TREEPATH="."
[ "${TREEPATH:0:1}" = "-" ] && TREEPATH="."

INFOFILE=$(mktemp)
DUMMYFILES=$(mktemp)
git -C "$TREEPATH" status --porcelain | while IFS= read -r line;
do
  case ${line:1:1} in
    'M')
      WORKTREE="[33mmodified[0m" ;;
    'T')
      WORKTREE="[33mfile type changed[0m" ;;
    'A')
      WORKTREE="[32madded[0m" ;;
    'D')
      WORKTREE="[31mdeleted[0m"
      if [[ ! "$line" =~ " -> " ]] && [ ! -e "$TREEPATH/${line:3}" ]; then
        echo "$TREEPATH/${line:3}" >> "$DUMMYFILES"
        touch "$TREEPATH/${line:3}"
      fi
      ;;
    'R')
      WORKTREE="[33mrenamed[0m" ;;
    'C')
      WORKTREE="[33mcopied[0m" ;;
    'U')
      WORKTREE="[33mupdated[0m" ;;
    '?')
      WORKTREE="untracked" ;;
    '!')
      WORKTREE="ignored" ;;
    ' ')
      case ${line:0:1} in
        'M')
          WORKTREE="[33mmodified[0m, [32mstaged[0m" ;;
        'T')
          WORKTREE="[33mfile type changed[0m, [32mstaged[0m" ;;
        'A')
          WORKTREE="[32madded[0m, [32mstaged[0m" ;;
        'R')
          WORKTREE="[33mrenamed[0m, [32mstaged[0m";;
        'C')
          WORKTREE="[33mcopied[0m, [32mstaged[0m" ;;
        'D')
          WORKTREE="[31mdeleted[0m, [32mstaged[0m"
          if [[ ! "$line" =~ " -> " ]] && [ ! -e "$TREEPATH/${line:3}" ]; then
            echo "$TREEPATH/${line:3}" >> "$DUMMYFILES"
            touch "$TREEPATH/${line:3}"
          fi
          ;;
        *)
          WORKTREE="unmatched?" ;;
      esac
      ;;
    *)
      WORKTREE="unmatched?" ;;
  esac
  if [ -d "$TREEPATH/${line:3}" ]; then
    echo -e "$TREEPATH/${line:3}*\n\t$WORKTREE" >> "$INFOFILE"
  fi
  if [[ "$line" =~ " -> " ]]; then
    arrow=" -> "
    line="${line:3}"
    echo -e "$TREEPATH/${line#*"$arrow"}\n\t$WORKTREE was ${line%"$arrow"*}" >> "$INFOFILE"
  else
    echo -e "$TREEPATH/${line:3}\n\t$WORKTREE" >> "$INFOFILE"
  fi
done

tree --dirsfirst --infofile "$INFOFILE" -C --gitignore "$@" | sed -z 's/─ \([^\n]*\)\n[^{\n]*{ untracked/─ [2m\1[0m/g; s/─ \([^\n]*\)\n[^{\n]*{ \([^\n]*\)/─ \1 - \2/g'
rm "$INFOFILE"
while IFS= read -r line;
do
  rm "$line"
done < "$DUMMYFILES"
rm "$DUMMYFILES"
