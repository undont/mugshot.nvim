SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# ──────────────────────────────────────────────────────────────────────────────
#  Colours
# ──────────────────────────────────────────────────────────────────────────────
GREEN  := \033[0;32m
YELLOW := \033[0;33m
CYAN   := \033[0;36m
BOLD   := \033[1m
NC     := \033[0m

INFO := printf "$(CYAN)› %s$(NC)\n"
OK   := printf "$(GREEN)✓$(NC) %s\n"

# lua sources luacheck and stylua operate on
LUA_PATHS := lua test plugin

.PHONY: help test test-unit test-nvim lint fmt fmt-check check

help: ## show this help message
	@cols=$$( { stty size </dev/tty; } 2>/dev/null | cut -d' ' -f2 ); \
	[ -n "$$cols" ] || cols=$$(tput cols 2>/dev/null); \
	case "$$cols" in ''|*[!0-9]*) cols=100;; esac; \
	[ "$$cols" -ge 40 ] || cols=100; \
	printf "\n  $(BOLD)mugshot.nvim$(NC) — make targets\n\n"; \
	awk -v width="$$cols" ' \
		function wrap(text, w, ind,    n, words, i, line, out, pad) { \
			pad = sprintf("%" ind "s", ""); \
			n = split(text, words, " "); line = ""; out = ""; \
			for (i = 1; i <= n; i++) { \
				if (line == "") line = words[i]; \
				else if (length(line) + 1 + length(words[i]) <= w - ind) line = line " " words[i]; \
				else { out = out line "\n" pad; line = words[i]; } \
			} \
			return out line; \
		} \
		/^##@ / { order[++cnt] = "S\t" substr($$0, 5); next } \
		/^[a-zA-Z_-]+:.*## / { \
			split($$0, a, /:.*## /); \
			order[++cnt] = "T\t" a[1] "\t" a[2]; \
			if (length(a[1]) > maxname) maxname = length(a[1]); \
		} \
		END { \
			ind = maxname + 5; \
			fmt = "  $(GREEN)%-" maxname "s$(NC)  %s\n"; \
			for (i = 1; i <= cnt; i++) { \
				split(order[i], p, "\t"); \
				if (p[1] == "S") printf "\n  $(YELLOW)%s$(NC)\n", p[2]; \
				else printf fmt, p[2], wrap(p[3], width, ind); \
			} \
			printf "\n"; \
		} \
	' $(MAKEFILE_LIST)

# ──────────────────────────────────────────────────────────────────────────────
#  Tests
# ──────────────────────────────────────────────────────────────────────────────
test: test-unit test-nvim ## run both suites (unit + headless-nvim)

test-unit: ## run the pure-lua unit suite (fast, no nvim)
	@$(INFO) "Running unit suite"
	@busted --run unit

test-nvim: ## run the headless-nvim suite (needs nlua on PATH)
	@$(INFO) "Running headless-nvim suite"
	@eval "$$(luarocks --lua-version=5.1 path)" && busted --lua=nlua --run nvim

# ──────────────────────────────────────────────────────────────────────────────
#  Quality
# ──────────────────────────────────────────────────────────────────────────────
lint: ## luacheck + stylua --check
	@$(INFO) "luacheck"
	@luacheck $(LUA_PATHS)
	@$(INFO) "stylua --check"
	@stylua --check $(LUA_PATHS)
	@$(OK) "lint clean"

fmt: ## format lua with stylua
	@stylua $(LUA_PATHS)
	@$(OK) "formatted $(LUA_PATHS)"

fmt-check: ## check formatting without writing
	@stylua --check $(LUA_PATHS)

check: lint test ## lint + test (the full gate)
	@$(OK) "all checks passed"
