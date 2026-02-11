# Raspberry Pi Metrics Screen (Chromium + Idle Trigger)

This setup creates a Chromium-based metrics screen that:
- starts after 5 minutes of user idle time,
- rotates through configured URLs,
- does not start while Chromium is actively playing media.

## Files
- `scripts/metrics-kiosk.conf`: URLs + timing config.
- `scripts/metrics-kiosk.sh`: Chromium kiosk rotator.
- `scripts/metrics-idle-watcher.sh`: idle and media playback watcher.
- `systemd/user/metrics-idle-watcher.service`: user service.
- `scripts/install.sh`: installer for the current user.

## Install on Raspberry Pi
1. Copy this folder to your Pi.
2. Run the installer:

```bash
cd home-screen/scripts
./install.sh
```

3. Configure URLs:

```bash
nano ~/.local/bin/metrics-kiosk.conf
```

4. Check status/logs:

```bash
systemctl --user status metrics-idle-watcher.service
journalctl --user -u metrics-idle-watcher.service -f
```

## Behavior
- Idle threshold defaults to `300000` ms (5 minutes).
- While idle and no Chromium media is playing, kiosk starts.
- Any activity (mouse/keyboard) stops kiosk.
- If a Chromium media session is `Playing`, kiosk stays off.

## Notes
- Idle detection uses `loginctl` (`systemd-logind`).
- Media detection uses `playerctl` MPRIS data for Chromium/Chrome players.
- If your Chromium package path differs, edit `CHROMIUM_BIN` in config.
