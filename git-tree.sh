#!/bin/bash
TREEPATH=${*: -1}
[ "$TREEPATH" = "$0" ] && TREEPATH="."
[ "${TREEPATH:0:1}" = "-" ] && TREEPATH="."
TREEPATH="${TREEPATH%"/"}"

INFOFILE=$(mktemp)
DUMMYFILES=$(mktemp)
SUBMODULES=$(mktemp)
TOPLEVEL="$(git -C "$TREEPATH" rev-parse --show-toplevel)"
gitstatus=$?
if [ "$gitstatus" -ne 0 ]; then
  exit "$gitstatus"
fi
PREFIX="$(git -C "$TREEPATH" rev-parse --show-prefix)"
git -C "$TOPLEVEL" config get --file .gitmodules --all --regex '\.path$' > "$SUBMODULES"
git -C "$TOPLEVEL" status --porcelain | while IFS= read -r line;
do
  FILENAME="${line:3}"
  WAS=""
  if [[ "$line" =~ " -> " ]]; then
    arrow=" -> "
    WAS="${FILENAME%"$arrow"*}"
    FILENAME="${FILENAME#*"$arrow"}"
  fi
  if [[ ! "$FILENAME" == "$PREFIX"* ]]; then
    # Ignore the status of files not in the requested directory
    continue
  fi
  if [ -n "$WAS" ]; then
    relative="$(realpath --relative-to="$(dirname "$FILENAME")" "$(dirname "$WAS")")"
    base="$(basename "$WAS")"
    WAS="$relative/$base"
  fi
  FILENAME="${FILENAME#"$PREFIX"}"
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
  if [[ "${line:0:2}" =~ 'D' ]] && [[ ! "$line" =~ " -> " ]] && [ ! -e "$TREEPATH/$FILENAME" ]; then
    echo "$TREEPATH/$FILENAME" >> "$DUMMYFILES"
    touch "$TREEPATH/$FILENAME"
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

  if [ -d "$TREEPATH/$FILENAME" ]; then
    if [ "${line: -1}" == "/" ]; then
      echo -e "$TREEPATH/$FILENAME**/*\n\t$STATUS" >> "$INFOFILE"
    else
      # Submodule
      case ${line:0:2} in
        ' M') STATUS="submodule, [33mmodified[0m" ;;
      esac
      echo -e "$TREEPATH/$FILENAME/**/*\n\tignore" >> "$INFOFILE"
      echo -e "${line:3}" >> "$SUBMODULES"
    fi
  fi
  if [ -n "$WAS" ]; then
    echo -e "$TREEPATH/$FILENAME\n\t$STATUS was $WAS" >> "$INFOFILE"
  else
    echo -e "$TREEPATH/$FILENAME\n\t$STATUS" >> "$INFOFILE"
  fi
done

cat "$SUBMODULES" | sort | uniq -u | while IFS= read -r line;
do
  FILENAME="${line#"$PREFIX"}"
  echo -e "$TREEPATH/${FILENAME}\n\tsubmodule" >> "$INFOFILE"
  echo -e "$TREEPATH/${FILENAME}/**/*\n\tignore" >> "$INFOFILE"
done

tree --dirsfirst --infofile "$INFOFILE" -C --gitignore "$@" | sed -z 's/─ \([^\n]*\)\n[^{\n]*{ untracked/─ [2m\1[0m/g; s/\n[^─\n]*── \([^\n]*\)\n[^{\n]*{ ignore//g; s/─ \([^\n]*\)\n[^{\n]*{ \([^\n]*\)/─ \1 - \2/g'
rm "$INFOFILE"
while IFS= read -r line;
do
  rm "$line"
done < "$DUMMYFILES"
rm "$DUMMYFILES"
rm "$SUBMODULES"
