# Manual integration checks

Run these checks with a real terminal or JupyterLab session before marking them complete. Automated specs cover the IRB PTY path and IRuby's display registry, but cannot confirm each frontend's rendering.

| Frontend | Check | Status |
| --- | --- | --- |
| Kitty | Image appears inline and the next prompt is intact | Not run |
| WezTerm | Image appears inline and the next prompt is intact | Not run |
| iTerm2 | Image appears inline and the next prompt is intact | Not run |
| Ghostty | Image appears inline and the next prompt is intact | Not run |
| VS Code integrated terminal | Image appears inline with image support enabled | Not run |
| tmux | Image appears inline and the next prompt is intact | Not run |
| JupyterLab | Image, chart SVG, and animation/fallback render in cells | Not run |
