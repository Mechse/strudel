# strudel

A Git commit-message generator powered by Apple's on-device language model.
No API keys. No cloud. No data leaves your Mac.



https://github.com/user-attachments/assets/7a431c9c-caf2-4022-a748-ed6b66a3bee7



## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Mechse/strudel/master/install.sh | bash
```

To audit the script before running:

```bash
curl -fsSL https://raw.githubusercontent.com/Mechse/strudel/master/install.sh
```

To uninstall:

```bash
sudo rm /usr/local/bin/strudel /usr/local/libexec/strudel-helper
```

## Roadmap

- [x] Tier 1: small diffs sent as-is
- [ ] Tier 2: compressed diff (`--stat` + `--unified=0`) for medium diffs
- [ ] Tier 3: per-file map-reduce for very large diffs
- [ ] `--candidates N` to generate multiple messages and let you pick
- [ ] `--message-only` flag for use in `prepare-commit-msg` git hooks
