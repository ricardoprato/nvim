-- ┌────────────────────────────┐
-- │ Base-branch resolution     │
-- └────────────────────────────┘
--
-- Answers exactly one question: which ref did the current branch fork from?
-- No branch name is hardcoded anywhere in this file — "main" and "develop" are
-- conventions, not guarantees, so every candidate comes from repo state.
--
-- Resolution cascade, most authoritative first; each miss falls through:
--   1. cached     git config branch.<current>.diffviewbase   (written by M.set)
--   2. git-flow   gitflow.branch.{master,develop} matched against the
--                 configured gitflow.prefix.* — the prefixes are read, not assumed
--   3. topology   the ref whose merge-base with HEAD is the most recent commit
--   4. remote     <remote>/HEAD, i.e. whatever the remote calls its default branch
-- A total miss returns nil; callers fall back to a branch picker.
--
-- The cache is the escape hatch: a picked base is written to the repo's local
-- git config, so a wrong guess is corrected once and never re-asked.

local M = {}

---Run git; return trimmed stdout, or nil on non-zero exit or empty output.
---@param args string[]
---@return string?
local function git(args)
	local cmd = { "git" }
	vim.list_extend(cmd, args)
	local res = vim.system(cmd, { text = true }):wait()
	if res.code ~= 0 then
		return nil
	end
	local out = vim.trim(res.stdout or "")
	return out ~= "" and out or nil
end

---Current branch name, or nil when detached HEAD / not a repo.
---@return string?
function M.current()
	return git({ "branch", "--show-current" })
end

---Remote tracking the given branch, else the first configured remote.
---@param branch string?
---@return string?
local function remote_name(branch)
	local tracked = branch and git({ "config", "--get", "branch." .. branch .. ".remote" })
	if tracked then
		return tracked
	end
	local remotes = git({ "remote" })
	return remotes and remotes:match("^[^\n]+") or nil
end

---Resolve a bare branch name to a ref that exists, preferring the local copy.
---@param name string?
---@param branch string?
---@return string?
local function existing_ref(name, branch)
	if not name then
		return nil
	end
	if git({ "rev-parse", "--verify", "--quiet", name .. "^{commit}" }) then
		return name
	end
	local remote = remote_name(branch)
	local qualified = remote and (remote .. "/" .. name)
	if qualified and git({ "rev-parse", "--verify", "--quiet", qualified .. "^{commit}" }) then
		return qualified
	end
	return nil
end

-- git-flow branches off master for these kinds, off develop for the rest.
local FROM_MASTER = { "hotfix", "support" }
local FROM_DEVELOP = { "feature", "bugfix", "release" }

---@param branch string
---@return string?
local function from_gitflow(branch)
	local master = git({ "config", "--get", "gitflow.branch.master" })
	local develop = git({ "config", "--get", "gitflow.branch.develop" })
	if not (master or develop) then
		return nil
	end
	local has_prefix = function(kind)
		local prefix = git({ "config", "--get", "gitflow.prefix." .. kind })
		return prefix ~= nil and vim.startswith(branch, prefix)
	end
	for _, kind in ipairs(FROM_MASTER) do
		if has_prefix(kind) then
			return master or develop
		end
	end
	for _, kind in ipairs(FROM_DEVELOP) do
		if has_prefix(kind) then
			return develop or master
		end
	end
	return nil
end

-- Rank every other ref by how recent its merge-base with HEAD is; the most
-- recent common ancestor is the branch we most plausibly forked from.
-- Ties (same-second commits, or several branches sitting on one fork point)
-- break toward the ref whose tip is closest to that merge-base — the branch
-- that has moved on least since the fork. Recency has to stay primary: a base
-- branch that raced ahead by 50 commits is still the base.
-- Excluded: the current branch, its remote-tracking copy (a merge-base at or
-- near HEAD would always win), and symbolic */HEAD refs (duplicates).
-- Still tied after both keys: prefer a local ref over its remote-tracking twin.
local FORK_POINT = [[
git for-each-ref --format='%(refname) %(refname:short)' refs/heads refs/remotes 2>/dev/null |
	while read -r full ref; do
		case "$ref" in
			"$CURRENT_REF"|*/"$CURRENT_REF"|*/HEAD) continue ;;
		esac
		mb=$(git merge-base HEAD "$ref" 2>/dev/null) || continue
		[ "$mb" = "$HEAD_SHA" ] && continue
		case "$full" in refs/heads/*) rank=0 ;; *) rank=1 ;; esac
		printf '%s %s %s\t%s\n' \
			"$(git show -s --format=%ct "$mb")" \
			"$(git rev-list --count "$mb..$ref")" \
			"$rank" \
			"$ref"
	done | sort -k1,1rn -k2,2n -k3,3n | head -n 1 | cut -f2
]]

---@param branch string?
---@return string?
local function from_topology(branch)
	local head = git({ "rev-parse", "HEAD" })
	if not head then
		return nil
	end
	local res = vim.system({ "sh", "-c", FORK_POINT }, {
		text = true,
		env = { HEAD_SHA = head, CURRENT_REF = branch or "" },
	}):wait()
	if res.code ~= 0 then
		return nil
	end
	local out = vim.trim(res.stdout or "")
	return out ~= "" and out or nil
end

---@param branch string?
---@return string?
local function from_remote_head(branch)
	local remote = remote_name(branch)
	if not remote then
		return nil
	end
	return git({ "symbolic-ref", "--short", "--quiet", "refs/remotes/" .. remote .. "/HEAD" })
end

---Resolve the base ref for a branch.
---@param branch string? defaults to the current branch
---@return string? base, string? source  which cascade step produced it
function M.resolve(branch)
	branch = branch or M.current()
	if not branch then
		return nil
	end

	local cached = existing_ref(git({ "config", "--get", "branch." .. branch .. ".diffviewbase" }), branch)
	if cached then
		return cached, "cached"
	end

	local flow = existing_ref(from_gitflow(branch), branch)
	if flow then
		return flow, "git-flow"
	end

	local topo = from_topology(branch)
	if topo then
		return topo, "merge-base"
	end

	local default = from_remote_head(branch)
	if default then
		return default, "remote HEAD"
	end

	return nil
end

---Persist a base ref for a branch in the repo's local git config.
---@param base string
---@param branch string? defaults to the current branch
---@return boolean
function M.set(base, branch)
	branch = branch or M.current()
	if not (branch and base) then
		return false
	end
	local res = vim.system({ "git", "config", "branch." .. branch .. ".diffviewbase", base }):wait()
	return res.code == 0
end

---Drop the cached base so resolution falls back to detection.
---@param branch string? defaults to the current branch
---@return boolean
function M.clear(branch)
	branch = branch or M.current()
	if not branch then
		return false
	end
	local res = vim.system({ "git", "config", "--unset", "branch." .. branch .. ".diffviewbase" }):wait()
	return res.code == 0
end

---Pick a base branch interactively; the choice is cached before `on_choice` runs.
---@param on_choice fun(base: string)
function M.pick(on_choice)
	local branch = M.current()
	Snacks.picker.git_branches({
		all = true,
		confirm = function(picker, item)
			picker:close()
			local base = item and item.branch
			if not base then
				return
			end
			M.set(base, branch)
			on_choice(base)
		end,
	})
end

---Open Diffview against the resolved base branch.
---Toggle-closes an open view first, mirroring <leader>gd / <leader>gv.
---@param opts { history?: boolean, pick?: boolean }?
---   history → commit-by-commit :DiffviewFileHistory instead of a flat diff
---   pick    → always prompt for the base, bypassing (and refreshing) the cache
function M.open(opts)
	opts = opts or {}
	if require("utils.diffview").close_if_open() then
		return
	end

	local run = function(base)
		-- Three dots: diff against the merge-base, so commits that landed on the
		-- base branch after the fork stay out of the review.
		if opts.history then
			vim.cmd(("DiffviewFileHistory --range=%s...HEAD"):format(base))
		else
			-- --imply-local makes the right pane the real working-tree file, so
			-- fixes can be typed straight into the review.
			vim.cmd(("DiffviewOpen %s...HEAD --imply-local"):format(base))
		end
	end

	if opts.pick then
		return M.pick(run)
	end

	local base, source = M.resolve()
	if not base then
		vim.notify("No base branch detected — pick one", vim.log.levels.WARN)
		return M.pick(run)
	end

	vim.notify(("Diffview base: %s (%s)"):format(base, source), vim.log.levels.INFO)
	run(base)
end

---:DiffviewBase [show|set|clear] — inspect or override the resolved base.
---@param opts table
function M.command(opts)
	local action = vim.trim(opts.args or "")
	action = action ~= "" and action or "show"

	local branch = M.current()
	if not branch then
		vim.notify("Not on a branch (detached HEAD?)", vim.log.levels.WARN)
		return
	end

	if action == "show" then
		local base, source = M.resolve(branch)
		if base then
			vim.notify(("%s → %s (%s)"):format(branch, base, source), vim.log.levels.INFO)
		else
			vim.notify(("%s → no base detected"):format(branch), vim.log.levels.WARN)
		end
	elseif action == "set" then
		M.pick(function(base)
			vim.notify(("%s → %s (cached)"):format(branch, base), vim.log.levels.INFO)
		end)
	elseif action == "clear" then
		M.clear(branch)
		local base, source = M.resolve(branch)
		vim.notify(
			base and ("%s → %s (%s)"):format(branch, base, source) or ("%s → no base detected"):format(branch),
			vim.log.levels.INFO
		)
	else
		vim.notify("Usage: :DiffviewBase [show|set|clear]", vim.log.levels.WARN)
	end
end

return M
