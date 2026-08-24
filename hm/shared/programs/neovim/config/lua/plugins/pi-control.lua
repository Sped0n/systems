local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "pi-control" })
end

local function current_target()
  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_get_option_value("buftype", { buf = buf }) ~= "" then
    return nil
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then return nil end

  local path = vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
  local mode = vim.fn.mode()
  if mode:match "[vV\22]" then
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes("<esc>", true, false, true),
      "x",
      true
    )
    local first = vim.api.nvim_buf_get_mark(buf, "<")[1]
    local last = vim.api.nvim_buf_get_mark(buf, ">")[1]
    if first == 0 or last == 0 then return nil end
    if first > last then first, last = last, first end
    return {
      buf = buf,
      path = path,
      first = first,
      last = last,
      visual = true,
    }
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  return {
    buf = buf,
    path = path,
    first = cursor[1],
    last = cursor[1],
    column = cursor[2] + 1,
    visual = false,
  }
end

local function normalize_message(message)
  local normalized = tostring(message or "")
    :gsub("\r\n", "\n")
    :gsub("[\r\n]+", " ")
    :gsub("%s+", " ")
    :gsub("^%s+", "")
    :gsub("%s+$", "")
  return normalized
end

local function diagnostics_for(target)
  local options = { severity = { max = vim.diagnostic.severity.WARN } }
  if target.visual then
    options.lnum = target.first - 1
    options.end_lnum = target.last - 1
  end
  local diagnostics = vim.diagnostic.get(target.buf, options)
  table.sort(diagnostics, function(left, right)
    if left.lnum == right.lnum then return left.col < right.col end
    return left.lnum < right.lnum
  end)
  return diagnostics
end

local function context_text(target, include_diagnostics)
  local reference = target.visual
      and string.format("%s:%d-%d", target.path, target.first, target.last)
    or string.format("%s:%d:%d", target.path, target.first, target.column)
  local lines = { "@" .. reference }
  if target.visual then
    vim.list_extend(
      lines,
      vim.api.nvim_buf_get_lines(target.buf, target.first - 1, target.last, false)
    )
  end

  if include_diagnostics then
    local diagnostics = diagnostics_for(target)
    if #diagnostics > 0 then table.insert(lines, "diagnostics:") end
    for _, diagnostic in ipairs(diagnostics) do
      local severity = diagnostic.severity == vim.diagnostic.severity.ERROR and "E" or "W"
      table.insert(
        lines,
        string.format(
          "[%s %d:%d] %s",
          severity,
          diagnostic.lnum + 1,
          diagnostic.col + 1,
          normalize_message(diagnostic.message)
        )
      )
    end
  end

  return table.concat(lines, "\n") .. "\n\n"
end

local function paste(target, text)
  vim.system(
    { "pi-control", "paste", target.sessionId, "--stdin", "--json" },
    { stdin = text, text = true },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          notify(vim.trim(result.stderr or "pi-control paste failed"), vim.log.levels.ERROR)
          return
        end
        notify("pasted context into " .. (target.sessionName or target.sessionId))
      end)
    end
  )
end

local function select_target(callback)
  vim.system(
    { "pi-control", "list", "--cwd", vim.fn.getcwd(), "--json" },
    { text = true },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          notify(vim.trim(result.stderr or "pi-control list failed"), vim.log.levels.ERROR)
          return
        end
        local ok, sessions = pcall(vim.json.decode, result.stdout)
        if not ok or type(sessions) ~= "table" then
          notify("invalid pi-control session list", vim.log.levels.ERROR)
          return
        end
        if #sessions == 0 then
          notify("no Pi sessions in current working directory", vim.log.levels.WARN)
          return
        end
        if #sessions == 1 then
          callback(sessions[1])
          return
        end
        vim.ui.select(sessions, {
          prompt = "Select Pi session:",
          format_item = function(session)
            return string.format(
              "%s  %s  %s",
              session.sessionName or "(unnamed)",
              session.state,
              session.sessionId:sub(-8)
            )
          end,
        }, function(session)
          if session then callback(session) end
        end)
      end)
    end
  )
end

local function paste_context(options)
  local target = current_target()
  if not target then
    notify("current buffer has no file context", vim.log.levels.ERROR)
    return
  end
  local text = context_text(target, options and options.diagnostics == true)
  select_target(function(session) paste(session, text) end)
end

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@param opts AstroCoreOpts
  opts = function(_, opts)
    local maps = assert(opts.mappings)

    maps.n["<Leader>pc"] = {
      function() paste_context() end,
      desc = "Paste context into Pi draft",
    }
    maps.x["<Leader>pc"] = maps.n["<Leader>pc"]

    maps.n["<Leader>pd"] = {
      function() paste_context { diagnostics = true } end,
      desc = "Paste context and diagnostics into Pi draft",
    }
    maps.x["<Leader>pd"] = maps.n["<Leader>pd"]
  end,
}
