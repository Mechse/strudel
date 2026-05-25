# saft

A Git commit-message generator powered by Apple's on-device language model.
No API keys. No cloud. No data leaves your Mac.

https://github.com/user-attachments/assets/d64bc256-22ed-4c2d-b0ea-f3fe18c991ca


## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Mechse/saft/master/install.sh | bash
```

To audit the script before running:

```bash
curl -fsSL https://raw.githubusercontent.com/Mechse/saft/master/install.sh
```

To uninstall:

```bash
sudo rm /usr/local/bin/saft /usr/local/libexec/saft-helper
```

## Roadmap

- [x] Tier 1: small diffs sent as-is
- [x] Tier 2: compressed diff (`--stat` + `--unified=0`) for medium diffs
- [ ] Tier 3: per-file map-reduce for very large diffs
- [ ] `--candidates N` to generate multiple messages and let you pick
- [ ] `--message-only` flag for use in `prepare-commit-msg` git hooks
