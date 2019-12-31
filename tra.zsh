#!/usr/bin/env zsh
# WTFPL
setopt err_exit
setopt pipe_fail
setopt extended_glob
setopt aliases
setopt prompt_percent

zmodload zsh/terminfo

alias tr="transmission-remote ${TR_HOST:-localhost}:${TR_PORT:-9091} ${TR_AUTH:+--authenv}"
alias trr='tr >/dev/null'
alias pager="colorize | sed -e $'s/$/ \e[K/' -e $'\\\$s/$/\e[J/' | command less -iEFKLQsrS"
alias editor="command ${EDITOR:?\$EDITOR is not set.} +'set buftype=nofile'"
vw() { eval $_vw }
colorize() { eval $_colorize }
local _colorize= _vw=pager
local tsel= tids= input=L lastinput= cmd= range= all_or_range= range_or_tsel= filter= file= autoupdate= fd=

trap 'echoti cvvis' EXIT
trap 'exit' INT TERM

msg() { print -nP "%B%F{${1:-default}}$2%f%b" }
confirm() {
  echoti cup $(echoti lines) 0
  echoti cvvis
  if { read -sqr "?$1? " } always { echoti civis } && sleep ${2:-1}; then
    msg green yes
    return 0
  else
    msg red no
    sleep .2
    return 1
  fi
}
error() { msg red "An error occurred.\e[K"; sleep .2 }

colorize_list() {
  sed \
      -e $'1s/.*/\e[1m\\0\e[0m/' \
      -e $'$s/.*/\e[1m\\0\e[0m/' \
      -e $'2,$s/ Done /\e[32m\\0\e[0m/' \
      -e $'2,$s/ 0% /\e[0;37m\\0\e[0m/' \
      -e $'2,$s/ 0\\.0/\e[0;37m\\0\e[0m/g' \
      -e $'2,$s/ None /\e[0;37m\\0\e[0m/g' \
      -e $'2,$s/ Stopped /\e[1;31m\\0\e[0m/' \
      -e $'2,$s/ Idle /\e[38;5;250m\\0\e[0m/g' \
      -e $'2,$s/ Unknown /\e[1;38;5;250m\\0\e[0m/g'
}
colorize_stat() {
  sed \
    -e $'s/^[^ ].*/\e[1m\\0\e[0m/' \
    -e $'s/ None /\e[38;5;250m\\0\e[0m/'
}
colorize_sessinfo() {
  sed \
    -e $'s/^[^ ].*/\e[1m\\0\e[0m/' \
    -e $'s/ Unlimited /\e[1;32m\\0\e[0m/' \
    -e $'s/ Yes$/\e[32m\\0\e[0m/;s/ No$/\e[31m\\0\e[0m/'
}
colorize_info() {
  sed \
    -e $'s/^NAME$/\e[4m\\0\e[24m/' \
    -e $'s/^[^ ].*/\e[1m\\0\e[21m/' \
    -e $'s/ Unlimited$/\e[1;32m\\0\e[0m/' \
    -e $'s/ None$/\e[38;5;250m\\0\e[0m/' \
}
colorize_trackers() {
  sed \
    -e $'s/Tracker [0-9]\\{1,3\\}: .*/\e[1m\\0\e[0m/' \
    -e $'s/: \\(.*\\)/: \e[32m\\1\e[0m/'
}
colorize_chunks() {
  awk '
BEGIN { print }
!NF { O=0; print; next }
{
  gsub("0", "·", $0); gsub("1", "█", $0)
  print sprintf("%8d%s", O, $0)
  O += 8*8
}'
}
colorize_peers() {
  sed \
    -e $'s/^[^ ].*/\e[1m\\0\e[0m/'
}
colorize_files() {
  sed \
    -e $'s/^[^ ].*/\e[1;4m\\0\e[0m/' \
    -e $'s/^  #.*/\e[1m\\0\e[0m/' \
    -e $'s/ Yes /\e[1;32m\\0\e[0m/;s/ No /\e[31m\\0\e[0m/' \
    -e $'s/ 0% /\e[37m\\0\e[0m/'
}

tr_list() {
  local sort_args=$1
  () {
    () {
      [[ $input == v ]] ||
        tids=(${(@f)$(awk '{print $1}' $1):1:-1})
      _colorize=colorize_list
      vw <$1
    } =(
      if [[ -n $sort_args ]]; then
        # TODO: Clean this shit up. Or don't... it's working.
        cat <(head -n1 <$1) \
            <(tail -n+2 <$1 | head -n-1 | sort -sk$sort_args) \
            <(tail -n1 <$1)
      else
        <$1
      fi
    )
  } =(tr -t$all_or_range -l)
  cmd=v
}

echoti civis
echoti clear
while :; do
  echoti home
  [[ $input =~ ^([[:digit:],-]+|a)?([^[:digit:],-]+)?$ ]]
  if [[ $match[1] == 'a' ]]; then
    range=all
  else
    if [[ $match[1] =~ ^[^[:digit:]].*$ ]]; then
      range=$tsel$match[1]
    else
      range=$match[1]
    fi
  fi
  cmd=$match[2]
  range_or_tsel=${${range:-$tsel}:-all}
  if [[ $cmd =~ ^[A-Z] ]]; then
    all_or_range=all
  else
    all_or_range=$range_or_tsel
  fi

  local ok=1
  _colorize=cat
  case $cmd in
  '') unset ok ;;
  ' ') # Noop.
    tsel=$range_or_tsel
    ;;
  \.) # Repeat.
    input=$lastinput
    continue ;;
  q) # Close.
    [[ ! $lastinput =~ ^[vlL]$ ]] && { input=v; continue }
    [[ $tsel != all ]] && { input=v; tsel=all; continue }
    exit ;;
  Z) unset ok ;;
  ZZ) # Exit.
    exit ;;
  l|L) # List.
    tsel=$range_or_tsel
    tr_list
    ;;
  A) # Active
    _colorize=colorize_list
    tr -tactive -l | vw || error
    ;;
  v) # View. (Non-destructive list.)
    tsel=$range_or_tsel
    tr_list ;;
  G) # Go last.
    tsel=${range:-$tids[-1]}
    input=$lastinput
    continue ;;
  g) unset ok ;;
  gg) # Go first.
    tsel=${range:-$tids[1]}
    input=$lastinput
    continue ;;
  j) # Down.
    tsel=${tids[$(($tids[(I)$tsel]+${range:-1}))]:-$tids[-1]}
    input=$lastinput
    continue ;;
  k) # Up.
    tsel=${tids[$(($tids[(I)$tsel]-${range:-1}))]:-$tids[1]}
    input=$lastinput
    continue ;;
  =) # Filter.
    exec {fd}< <(tr -t$tsel -l | colorize_list | head -n-1 | fzf --ansi --multi --query=$filter --print-query --header-lines=1 --bind alt-enter:select-all+accept) &&
    read -u $fd filter &&
    local _tids=($(print -o ${(@f)$(awk '{print $1}' <&$fd)}))
    tsel=()
    for ((i=1; i <= $#_tids; ++i)); do
      local start=$_tids[i]
      local end=$start
      for ((;end + 1 == ${_tids[i + 1]:--1}; ++end, ++i)); do :; done
      if [[ $start < $end ]]; then
        tsel+=($start-$end)
      else
        tsel+=($start)
      fi
    done
    unset _tids

    tsel=${(j:,:)tsel}
    input=l
    continue
    ;;
  s|S) # Start/Start all.
    trr -t$all_or_range --start || error
    input=$lastinput
    continue
    ;;
  p|P) # Pause/Pause all.
    trr -t$all_or_range --stop || error
    input=$lastinput
    continue
    ;;
  V) # Verify.
    tsel=$range_or_tsel
    if confirm "Verify torrent(s) $tsel?" 2; then
      trr -t$tsel --verify || error
    fi
    input=$lastinput
    continue
    ;;
  i) # Info.
    _colorize=colorize_info
    tsel=$range_or_tsel
    tr -t$tsel -i | vw || error
    ;;
  r) # Peers.
    _colorize=colorize_peers
    tsel=$range_or_tsel
    tr -t$tsel -ip | vw || error
    ;;
  c) # Chunks.
    _colorize=colorize_chunks
    tsel=$range_or_tsel
    tr -t$tsel -ic | vw || error
    ;;
  f) # Files.
    _colorize=colorize_files
    tsel=$range_or_tsel
    tr -t$tsel -if | vw || error
    ;;
  F) # Filter files.
    tsel=$range_or_tsel
    if [[ $tsel =~ ^[[:digit:]]$ ]]; then
      () {
        () {
          local yes_file=$1 orig_file=$2
          if $EDITOR +'setf transmission-files' -- $yes_file \
            && [[ $yes_file -nt $orig_file ]]; then
            local no_files=${(j:,:)${(@f)$(
              comm -23 <(awk '$4=="Yes"' $orig_file | sort) <(sort $yes_file) | cut -d: -f1)}}
            [[ -z $no_files ]] || tr -t$tsel --no-get $no_files || error

            local yes_files=${(j:,:)${(@f)$(awk '$4=="No"' $yes_file | cut -d: -f1)}}
            [[ -z $yes_files ]] || tr -t$tsel --get $yes_files || error
          fi
        } $1 <(<$1)
      } =(tr -t$tsel -if | tail -n+3)
      input=f
      continue
    fi
    ;;
  t) # Trackers.
    _colorize=colorize_trackers
    tsel=$range_or_tsel
    tr -t$tsel -it | vw || error
    ;;
  I) # Session info.
    _colorize=colorize_sessinfo
    tr -si | vw || error
    ;;
  T) # Session stat.
    _colorize=colorize_stat
    tr -st | vw || error
    ;;
  d|D) unset ok ;;
  dd) # Remove.
    [[ $lastinput != i ]] && { input=i; continue }
    tsel=$range_or_tsel
    if confirm "Remove torrent(s) $tsel"; then
      trr -t$tsel --remove || error
    fi
    input=L
    continue ;;
  DD) # Delete.
    [[ $lastinput != i ]] && { input=i; continue }
    tsel=$range_or_tsel
    if confirm "Remove **AND DELETE** torrent(s) $tsel" 2; then
      trr -t$tsel --remove-and-delete || error
    fi
    input=L
    continue ;;
  Q) unset ok ;;
  QQ) # Quit daemon.
    if confirm "Exit Transmission"; then
      trr -tall --stop &&
      trr -tall --reannounce &&
      trr -tall --start &&
      trr --exit || error
    fi
    input=L
    continue ;;
  o|O) # Order by...
    unset ok ;;
  [oO]o) tr_list 2hr ;;
  [oO]O) tr_list 2h  ;;
  [oO]h) tr_list 3hr ;;
  [oO]H) tr_list 3h  ;;
  [oO]t) tr_list 5hr ;;
  [oO]T) tr_list 5h  ;;
  [oO]u) tr_list 6hr ;;
  [oO]U) tr_list 6h  ;;
  [oO]d) tr_list 7hr ;;
  [oO]D) tr_list 7h  ;;
  [oO]r) tr_list 8hr ;;
  [oO]R) tr_list 8h  ;;
  [oO]s) tr_list 9   ;;
  [oO]S) tr_list 9r  ;;
  [oO]n) tr_list 10  ;;
  [oO]N) tr_list 10r ;;
  b) # Browse.
    tsel=$range_or_tsel
    for file in ${(@f)"$(tr -t$tsel -i | awk -F': ' '/^  Name: / {nam=substr($0,9)} /^  Location: / {dir=substr($0,13);print dir "/" nam}')"}; do
      zsh -ic "open ${(q)file}" || :
    done
    input=$lastinput
    continue ;;
  e) # View in $EDITOR.
    _vw=editor
    input=$lastinput
    continue ;;
  U) # Autoupdate.
    if [[ -z $autoupdate || -n $range ]]; then
      autoupdate=${range:-3}
    else
      autoupdate=
    fi
    echoti cup $(echoti lines) 0
    msg '' "Autoupdate: ${${autoupdate:+${autoupdate}s}:-no}."
    sleep .5
    input=$lastinput
    continue ;;
  *)
    input=
    unset ok
    ;;
  esac

  if [[ -v ok ]]; then
    lastinput=$cmd
    input=
    if [[ -z $input && $_vw != pager ]]; then
      _vw=pager
      input=.
      continue
    fi
  fi

  local args=(-t $autoupdate)
  [[ -n $autoupdate && -z $input ]] || args=()
  echoti cup $(echoti lines) 0
  print -n $tsel
  [[ $tsel =~ ^[[:digit:]]+$ ]] && (($#tids > 1)) &&
    print -n " ($((100 * (tids[(I)$tsel] - 1) / ($#tids - 1)))%)"
  echoti el
  echoti cup $(echoti lines) $(($(echoti cols) - 11))
  print -n $input
  read -srk1 $args char || { input=.; continue }
  if [[ char =~ [[:print:]] ]]; then
    print -n $char
    input+=$char
  fi
done
# vi:ts=2 sw=2
