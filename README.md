# keepass4brute (Multithreaded Mod)

A multithreaded bash script for brute-forcing KeePass `.kdbx` database files using `keepassxc-cli`. Based on the original [keepass4brute](https://github.com/r3nt0n/keepass4brute) by r3nt0n.

---

## Requirements

- `keepassxc-cli` (included with KeePass XC)
- `bash`
- A wordlist (e.g. `rockyou.txt`)

### Install keepassxc-cli

```bash
sudo apt install keepassxc -y
```

---

## Usage

```bash
chmod +x keepass4brute.sh
./keepass4brute.sh <kdbx-file> <wordlist> [threads]
```

### Arguments

| Argument | Description | Required |
|---|---|---|
| `<kdbx-file>` | Path to the `.kdbx` database file | Yes |
| `<wordlist>` | Path to the wordlist file | Yes |
| `[threads]` | Number of parallel threads (default: 4) | No |

### Examples

```bash
# Basic usage with default 4 threads
./keepass4brute.sh Database.kdbx rockyou.txt

# Use 16 threads for faster cracking
./keepass4brute.sh Database.kdbx rockyou.txt 16
```

---

## Features

- **Multithreaded** — runs multiple password attempts in parallel via a FIFO pipe
- **Live progress** — shows words tested, attempts per minute, and estimated time remaining
- **Early exit** — all threads stop immediately when the password is found
- **Special character safe** — handles passwords containing quotes, semicolons, and other shell-special characters
- **GNU parallel support** — automatically uses `parallel` if installed, falls back to native bash workers

---

## Tips

- More threads = faster cracking, but diminishing returns above your CPU core count
- KDBX 4 with Argon2 is intentionally slow to crack — expect low attempts/minute
- If rockyou.txt isn't working, try a targeted wordlist based on CTF hints
- On WSL, fix Windows line endings before running: `sed -i 's/\r//' keepass4brute.sh`

---

## Output

```
keepass4brute 1.4-mt by r3nt0n (multithreaded mod)
https://github.com/r3nt0n/keepass4brute

[+] 4800/14344391 tested | 16000/min | ETA: 14h 55m
[*] Password found: letmein123
```

---

## Credits

Original tool created by **r3nt0n**

- GitHub: [https://github.com/r3nt0n/keepass4brute](https://github.com/r3nt0n/keepass4brute)
- Original version: 1.3 (25/11/2022)

This fork adds multithreading support via parallel bash workers and a FIFO-based job queue. All core logic and credit belongs to the original author.