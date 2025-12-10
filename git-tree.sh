#!/bin/bash
TREEPATH=${*: -1}
[ "$TREEPATH" = "$0" ] && TREEPATH="."
[ "${TREEPATH:0:1}" = "-" ] && TREEPATH="."

INFOFILE=$(mktemp)
DUMMYFILES=$(mktemp)
SUBMODULES=$(mktemp)
# TODO: Use git rev-parse --show-prefix to ignore changes not in listed directory and correctly create relative paths
git -C "$TREEPATH" config get --file .gitmodules --all --regex '\.path$' > "$SUBMODULES"
git -C "$TREEPATH" status --porcelain | while IFS= read -r line;
do
  # TODO: Add back deleted files and "was" tracking
  STATUS=""
  INDEX=""
  case ${line:0:1} in
    'M') INDEX="[33mmodified[0m" ;;
    'A') INDEX="[32madded[0m" ;;
    'D') INDEX="[31mdeleted[0m" ;;
    'R') INDEX="[33mrenamed[0m" ;;
    'C') INDEX="[33mcopied[0m" ;;
  esac
  WORKTREE=""
  case ${line:1:1} in
    'M') WORKTREE="[33mmodified[0m" ;;
    'A') WORKTREE="[32madded[0m" ;;
    'D') WORKTREE="[31mdeleted[0m" ;;
    'R') WORKTREE="[33mrenamed[0m" ;;
    'C') WORKTREE="[33mcopied[0m" ;;
  esac
  MERGE=""
  case ${line:0:2} in
    'DD') MERGE="[31munmerged[0m, [33mboth deleted[0m" ;;
    'AU') MERGE="[31munmerged[0m, [33madded by us[0m" ;;
    'UD') MERGE="[31munmerged[0m, [33mdeleted by them[0m" ;;
    'UA') MERGE="[31munmerged[0m, [33madded by them[0m" ;;
    'DU') MERGE="[31munmerged[0m, [33mdeleted by us[0m" ;;
    'AA') MERGE="[31munmerged[0m, [33mboth added[0m" ;;
    'UU') MERGE="[31munmerged[0m, [33mboth modified[0m" ;;
    '??') MERGE="untracked" ;;
  esac
  if [[ "${line:0:2}" =~ 'D' ]] && [[ ! "$line" =~ " -> " ]] && [ ! -e "$TREEPATH/${line:3}" ]; then
    echo "$TREEPATH/${line:3}" >> "$DUMMYFILES"
    touch "$TREEPATH/${line:3}"
  fi
  if [ -n "$MERGE" ]; then
    STATUS="$MERGE"
  else
    if [ -n "$INDEX" ]; then
      STATUS="$INDEX, [32mstaged[0m"
    fi
    if [ -n "$WORKTREE" ]; then
      if [ -n "$STATUS" ]; then
        STATUS="$STATUS, further "
      fi
      STATUS="$STATUS$WORKTREE"
    fi
  fi

  if [ -d "$TREEPATH/${line:3}" ]; then
    if [ "${line: -1}" == "/" ]; then
      echo -e "$TREEPATH/${line:3}**/*\n\t$STATUS" >> "$INFOFILE"
    else
      # Submodule
      case ${line:0:2} in
        ' M') STATUS="submodule, [33mmodified[0m" ;;
      esac
      echo -e "$TREEPATH/${line:3}/**/*\n\tignore" >> "$INFOFILE"
      echo -e "${line:3}" >> "$SUBMODULES"
    fi
  fi
  if [[ "$line" =~ " -> " ]]; then
    arrow=" -> "
    line="${line:3}"
    echo -e "$TREEPATH/${line#*"$arrow"}\n\t$STATUS was ${line%"$arrow"*}" >> "$INFOFILE"
  else
    echo -e "$TREEPATH/${line:3}\n\t$STATUS" >> "$INFOFILE"
  fi
done

cat "$SUBMODULES" | sort | uniq -u | while IFS= read -r line;
do
  echo -e "$TREEPATH/${line}\n\tsubmodule" >> "$INFOFILE"
  echo -e "$TREEPATH/${line}/**/*\n\tignore" >> "$INFOFILE"
done

tree --dirsfirst --infofile "$INFOFILE" -C --gitignore "$@" | sed -z 's/─ \([^\n]*\)\n[^{\n]*{ untracked/─ [2m\1[0m/g; s/\n[^─\n]*── \([^\n]*\)\n[^{\n]*{ ignore//g; s/─ \([^\n]*\)\n[^{\n]*{ \([^\n]*\)/─ \1 - \2/g'
rm "$INFOFILE"
while IFS= read -r line;
do
  rm "$line"
done < "$DUMMYFILES"
rm "$DUMMYFILES"
rm "$SUBMODULES"
