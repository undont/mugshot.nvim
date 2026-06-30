<div align="center">

# mugshot.nvim

**A git blame card for the line under your cursor, with the commit author's avatar rendered inline in the terminal.**

[![CI](https://img.shields.io/github/actions/workflow/status/undont/mugshot.nvim/ci.yml?branch=main&style=flat&logo=githubactions&logoColor=white&label=CI)](https://github.com/undont/mugshot.nvim/actions)
[![Release](https://img.shields.io/github/v/release/undont/mugshot.nvim?style=flat&logo=github&logoColor=white&label=Release&color=6366F1)](https://github.com/undont/mugshot.nvim/releases/latest)
[![Licence](https://img.shields.io/github/license/undont/mugshot.nvim?style=flat&label=licence&color=6366F1)](LICENCE)
[![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?style=flat&logo=lua&logoColor=white)](https://www.lua.org)
[![Neovim](https://img.shields.io/badge/Neovim-0.10+-57A143?style=flat&logo=neovim&logoColor=white)](https://neovim.io)
[![macOS](https://img.shields.io/badge/macOS-supported-6e7681?style=flat&logo=apple&logoColor=white)]()
[![Linux](https://img.shields.io/badge/Linux-supported-6e7681?style=flat&logo=linux&logoColor=white)]()

[Features](#features) · [Requirements](#requirements) · [Installation](#installation) · [Usage](#usage) · [Configuration](#configuration) · [Development](#development)

</div>

---

`git blame` tells you who and when; it doesn't put a face to the line. mugshot opens a small float for the line under the cursor showing the author, the relative and absolute time, the short sha, and the commit summary, with the author's avatar drawn in the corner when your terminal can draw images.

The avatar is resolved from the commit's GitHub author, falling back to Gravatar and then a generated silhouette. Everything off the blame (the GitHub lookup, the download, the resize) runs async, so the card opens immediately. Without image support the same card renders as plain text.

---

## Features

- **Blame card** for the line under the cursor, showing author, relative + absolute time, short sha, and summary
- **Inline author avatars** drawn via the kitty graphics protocol (through [image.nvim](https://github.com/3rd/image.nvim))
- **Avatar resolution** through the commit's GitHub author, then Gravatar, then a magick-drawn placeholder silhouette
- **Card actions** for opening the commit page, copying the full sha, and jumping to the PR that introduced the line
- **Disk-cached avatars** keyed by GitHub login, so a contributor's later commits reuse the same face
- **Capability gating** that checks image.nvim, the terminal protocol, and tmux passthrough, and degrades to a text-only card when any is missing
- **Zero-config command** with `:Mugshot` working on load; `setup()` is only needed to bind the trigger keymap

---

## Requirements

- Neovim 0.10+ (uses `vim.system`)
- git on `PATH`

Avatars are optional; without the pieces below the card still renders as text.

- [image.nvim](https://github.com/3rd/image.nvim) and a terminal that speaks the kitty graphics protocol (kitty, Ghostty, WezTerm)
- ImageMagick (`magick`) to resize avatars (image.nvim's dependency anyway)
- `curl` to download avatars
- `gh` authenticated, for the GitHub avatar and PR lookups
- Inside tmux, `allow-passthrough` set to `on`

---

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "undont/mugshot.nvim",
  dependencies = { "3rd/image.nvim" }, -- optional, for avatars
  config = function()
    require("mugshot").setup()
  end,
}
```

`setup()` is only needed to change defaults and bind the trigger keymap. The `:Mugshot` command is registered on startup either way. Pin a release with `version = "v0.0.1"`.

### vim.pack (Neovim 0.12+)

```lua
vim.pack.add({ "https://github.com/undont/mugshot.nvim" })
require("mugshot").setup()
```

Pin a release with `{ src = "https://github.com/undont/mugshot.nvim", version = "v0.0.1" }`.

---

## Usage

`:Mugshot`, or the default `gb` keymap, opens the blame card for the current line. The card is a focusable float; focus it to use the actions, and it dismisses itself as soon as focus leaves.

| Key | Action |
|---|---|
| `o` | Open the commit page in the browser |
| `y` | Copy the full sha to the unnamed and system registers |
| `p` | Open the PR that introduced the line (falls back to the commit page) |
| `q` / `<Esc>` | Close the card |

The commit, copy, and PR actions need a GitHub `origin` remote. A line that isn't committed yet (the all-zero blame sha) shows the card but skips the avatar and remote actions.

---

## Configuration

`setup()` merges over these defaults:

```lua
require("mugshot").setup({
  keymap = "gb",                 -- trigger that opens the card; false to disable
  actions = {                    -- buffer-local keys inside the focused card
    open_commit = "o",
    copy_sha = "y",
    open_pr = "p",
    dismiss = { "q", "<Esc>" },
  },
  hint_row = true,               -- render the dim action-hint row at the foot of the card
  avatar = {
    width = 8,                   -- cell width of the avatar block
    height = 4,                  -- cell height of the avatar block
    size = 128,                  -- pixel size the cached png is pre-resized to
    shape = "square",            -- "square" | "rounded"
  },
  cache = {
    dir = vim.fn.stdpath("cache") .. "/mugshot",
    login_ttl = 30 * 24 * 60 * 60, -- ttl for the email -> login lookup, seconds
  },
  gravatar = true,               -- fall back to Gravatar when GitHub has no linked user
})
```

---

## tmux and image bleed

Inside tmux, a kitty-graphics image is drawn at the terminal level, and a tmux **window or session switch never reaches Neovim as a window event**, so the avatar can linger on screen and bleed across panes. This is a tmux + kitty-graphics limitation, not specific to mugshot (see [image.nvim #233](https://github.com/3rd/image.nvim/issues/233), [kitty #2457](https://github.com/kovidgoyal/kitty/issues/2457)).

mugshot dismisses the card and clears the image on `FocusLost`, which covers tmux switches **only if tmux forwards focus events**:

```tmux
# ~/.tmux.conf
set -g focus-events on
set -g allow-passthrough on
```

For coverage independent of focus events, enable image.nvim's own tmux gating in your `image.setup()`:

```lua
require("image").setup({
  tmux_show_only_in_active_window = true, -- needs `set -g visual-activity off` in tmux
})
```

---

## How it works

The card is built from one `git blame --porcelain` of the current line; everything after that is async.

```
git blame -L <line> --porcelain
        │
        ▼
  resolve avatar ──▶ GitHub commit author (gh api)
        │      └──▶ Gravatar (curl, when the email has one)
        │      └──▶ generated placeholder silhouette
        ▼
   disk cache ──▶ curl download + magick resize, keyed by GitHub login
        │
        ▼
   render float ──▶ image.nvim draws the avatar, or text-only fallback
```

The GitHub lookup is the only rate-limited call (5k/hr authenticated), and is skipped for unpushed commits.

---

## Development

```sh
make test        # both suites (unit + headless-nvim)
make test-unit   # pure-Lua unit tests only (busted, no Neovim)
make test-nvim   # headless-nvim tests (needs nlua on PATH)
make lint        # luacheck + stylua --check
make fmt         # format with stylua
make check       # full quality gate: lint + test
make help        # all targets
```

Modules under `test/unit` are pure Lua and must not touch the `vim` API; Neovim-only behaviour (the float, image rendering, capability detection) is tested headless under `test/nvim`.

---

## Licence

[MIT](LICENCE)
