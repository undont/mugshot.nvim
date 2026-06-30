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

help:
	@printf "\n  $(BOLD)mugshot.nvim$(NC) — make targets\n\n"
	@printf "  $(YELLOW)test$(NC)\n"
	@printf "    $(GREEN)%-11s$(NC) %s\n" "test" "run both suites (unit + headless-nvim)"
	@printf "    $(GREEN)%-11s$(NC) %s\n" "test-unit" "run the pure-lua unit suite (fast, no nvim)"
	@printf "    $(GREEN)%-11s$(NC) %s\n" "test-nvim" "run the headless-nvim suite (needs nlua)"
	@printf "  $(YELLOW)quality$(NC)\n"
	@printf "    $(GREEN)%-11s$(NC) %s\n" "lint" "luacheck + stylua --check"
	@printf "    $(GREEN)%-11s$(NC) %s\n" "fmt" "format lua with stylua"
	@printf "    $(GREEN)%-11s$(NC) %s\n" "fmt-check" "check formatting without writing"
	@printf "    $(GREEN)%-11s$(NC) %s\n" "check" "lint + test (the full gate)"
	@printf "\n"

# ──────────────────────────────────────────────────────────────────────────────
#  Tests
# ──────────────────────────────────────────────────────────────────────────────
test: test-unit test-nvim

test-unit:
	@$(INFO) "Running unit suite"
	@busted --run unit

test-nvim:
	@$(INFO) "Running headless-nvim suite"
	@eval "$$(luarocks --lua-version=5.1 path)" && busted --lua=nlua --run nvim

# ──────────────────────────────────────────────────────────────────────────────
#  Quality
# ──────────────────────────────────────────────────────────────────────────────
lint:
	@$(INFO) "luacheck"
	@luacheck $(LUA_PATHS)
	@$(INFO) "stylua --check"
	@stylua --check $(LUA_PATHS)
	@$(OK) "lint clean"

fmt:
	@stylua $(LUA_PATHS)
	@$(OK) "formatted $(LUA_PATHS)"

fmt-check:
	@stylua --check $(LUA_PATHS)

check: lint test
	@$(OK) "all checks passed"
