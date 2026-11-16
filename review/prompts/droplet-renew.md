# Prompt for the Claude Code session in Warp: vault token renewal (task T7, step 6)

John: paste everything below the line into Claude Code in Warp. It asks your yes before each change.

---

Task T7 step 6 of the harness review in github.com/jcallahanp/new-project-template (branch
`claude/awesome-darwin-di1t8o`). Reach the droplet with `ssh johns-ubuntu '<command>'`. Never print
a token. Before each change, say in one line what it changes and wait for John's yes.

Why: the vault tokens in `~/.config/openbao/*.token` are periodic (30 days). Nothing renews them, so
the `claude` and `silk` tokens expire on 2026-12-16, and each new `vault-project` token 30 days
after its last renewal. An expired token stops every run that uses the vault.

1. Change (ask first): a script `~/.local/bin/vault-renew` that, for each file in
   `~/.config/openbao/*.token`, runs `bao token renew` with that token (read from the file into the
   command's environment only, never printed), and on any failure runs `notify "vault-renew: <file
   name> failed"`. Exit non-zero if any renewal failed.
2. Change (ask first): a systemd user service and timer `vault-renew.service` / `vault-renew.timer`
   (daily, `Persistent=true`, a random delay up to 1 hour), enabled with
   `systemctl --user enable --now vault-renew.timer`. Linger is already on for `john`.
3. Check: `systemctl --user start vault-renew.service`, then exit status 0; for each token,
   `bao token lookup` shows `ttl` close to 720h (print only the file name and the ttl);
   `systemctl --user list-timers vault-renew.timer` shows the next run.
4. Commit: in `~/projects/new-project-template` on the droplet, `git pull --ff-only`, append
   `## 15. T7 token renewal (date)` to `review/inventory/droplet.md` with the check output (no
   tokens), commit `inventory: T7 token renewal`, push. Ask John whether copies of the script and
   unit files should also go into `linux-droplet-migration` (`setup/droplet/`); only on his yes.
5. Report in three lines or fewer.
