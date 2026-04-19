#!/bin/bash

version="1.4-mt"
/bin/echo -e "keepass4brute $version by r3nt0n (multithreaded mod)"
/bin/echo -e "https://github.com/r3nt0n/keepass4brute\n"

if [ $# -lt 2 ]
then
  /bin/echo "Usage $0 <kdbx-file> <wordlist> [threads]"
  exit 2
fi

KDBX=$1
WORDLIST=$2
THREADS=${3:-4}

dep="keepassxc-cli"
command -v $dep >/dev/null 2>&1 || { /bin/echo >&2 "Error: $dep not installed. Aborting."; exit 1; }

n_total=$(wc -l < "$WORDLIST")
start_time=$(date +%s)
found_file=$(mktemp)
counter_file=$(mktemp)
echo "0" > "$counter_file"

cleanup() {
  rm -f "$found_file" "$counter_file" "$counter_file.lock"
  kill 0 2>/dev/null
}
trap cleanup EXIT INT TERM

# Progress monitor
monitor() {
  while true; do
    sleep 2
    [ -s "$found_file" ] && break
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    n_tested=$(cat "$counter_file" 2>/dev/null || echo 0)
    if [ "$elapsed" -gt 0 ] && [ "$n_tested" -gt 0 ]; then
      apm=$((n_tested * 60 / elapsed))
      remaining=$((n_total - n_tested))
      eta_sec=$((remaining * 60 / (apm + 1)))
      eta_min=$((eta_sec / 60))
      eta_s=$((eta_sec % 60))
      /bin/echo -e "\r[+] $n_tested/$n_total tested | $apm/min | ETA: ${eta_min}m ${eta_s}s    "
    fi
  done
}

monitor &
MONITOR_PID=$!

# Worker function - reads from shared fd
worker() {
  while true; do
    [ -s "$found_file" ] && break

    # Read a line atomically
    local line
    { flock 100; IFS= read -r line <&100 || { flock -u 100; break; }; flock -u 100; } 100<"$WORDLIST"

    [ -z "$line" ] && break

    /bin/echo "$line" | keepassxc-cli open "$KDBX" &>/dev/null
    if [ $? -eq 0 ]; then
      echo "$line" > "$found_file"
      break
    fi

    # Increment counter
    { flock 200; count=$(cat "$counter_file"); echo $((count + 1)) > "$counter_file"; } 200>"$counter_file.lock"
  done
}

# Use GNU parallel if available (handles special chars properly)
if command -v parallel &>/dev/null; then
  cat "$WORDLIST" | parallel -j "$THREADS" -q /bin/bash -c \
    '/bin/echo {} | keepassxc-cli open "$1" &>/dev/null && echo {} > "$2"' \
    _ "$KDBX" "$found_file"
else
  # Spawn worker threads manually
  for i in $(seq 1 "$THREADS"); do
    worker &
  done

  # Feed words to workers via a named pipe
  PIPE=$(mktemp -u)
  mkfifo "$PIPE"

  # Rewrite using a fifo-based approach
  exec 100<>"$PIPE"
  rm "$PIPE"

  cat "$WORDLIST" >&100 &

  for i in $(seq 1 "$THREADS"); do
    (
      while true; do
        [ -s "$found_file" ] && exit
        IFS= read -r -u 100 line || exit
        /bin/echo "$line" | keepassxc-cli open "$KDBX" &>/dev/null
        if [ $? -eq 0 ]; then
          echo "$line" > "$found_file"
          exit
        fi
        { flock 200; count=$(cat "$counter_file"); echo $((count + 1)) > "$counter_file"; } 200>"$counter_file.lock"
      done
    ) &
  done

  wait
fi

kill $MONITOR_PID 2>/dev/null
echo ""

if [ -s "$found_file" ]; then
  password=$(cat "$found_file")
  /bin/echo "[*] Password found: $password"
  exit 0
else
  /bin/echo "[!] Wordlist exhausted, no match found"
  exit 3
fi
