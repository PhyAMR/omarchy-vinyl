# Vinyl

A bar widget for the [Omarchy](https://omarchy.org) shell: a vinyl record drawn in
thin lines that spins while your computer plays sound, with a live sound wave
running out of the stylus.

- **Any sound drives it.** The level comes from a PipeWire peak monitor on the
  default output, so no cava or other helper is needed. The animation only runs
  while there is sound (or while the record coasts to a stop), so an idle bar
  costs nothing.
- **Media controls on hover.** Hovering swaps the wave for previous / play-pause /
  next, acting on the MPRIS player the Omarchy media service considers active
  (Spotify, browsers, mpv, …). Scroll over the widget to switch players; click
  the record to play/pause.
- Follows the bar's foreground colour, so it matches every theme.

## Install

```bash
omarchy plugin add https://github.com/PhyAMR/omarchy-vinyl --enable
```

Update later with `omarchy plugin update phuniverse.vinyl`.

## Settings

In the bar's widget settings:

| Setting | Default | Range |
|---|---|---|
| Wave length (px) | 44 | 16–120 |
| Line width | 1 | 0.5–2 |
| Sensitivity | 1.5 | 0.5–4 |

## Develop

Clone anywhere and link it into the plugins folder; edits show up after
`omarchy-shell shell rescanPlugins` (or a shell restart):

```bash
git clone git@github.com:PhyAMR/omarchy-vinyl.git ~/code/omarchy-vinyl
ln -sfn ~/code/omarchy-vinyl ~/.config/omarchy/plugins/phuniverse.vinyl
omarchy plugin validate ~/code/omarchy-vinyl
```

## License

MIT, see [LICENSE](LICENSE).
