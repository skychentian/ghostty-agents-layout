local M = {}

M.config = {
  appNames = {
    "ghostty",
    "Ghostty",
    "Terminal",
    "iTerm",
    "iTerm2",
    "Warp",
    "WezTerm",
    "Alacritty",
    "kitty",
    "Tabby",
    "Hyper",
  },
  includeAllWindowsForApps = { "ghostty", "Ghostty" },
  includeAllTerminalWindows = false,
  agentTitleHints = {
    "Claude Code",
    "claude code",
    "claude",
    "Codex",
    "codex",
    "agent",
    "agents",
    "✳",
    "⠐",
  },
  hotkey = { { "ctrl", "alt", "cmd" }, "G" },
  listHotkey = { { "ctrl", "alt", "cmd", "shift" }, "G" },
  sidebarHotkey = { { "ctrl", "alt", "cmd" }, "S" },
  desktopHotkey = { { "ctrl", "alt", "cmd" }, "D" },
  margin = 12,
  gap = 8,
  sidebarWidth = 320,
  sidebarContentGap = 10,
  expandMargin = 14,
  expandAnimation = 0.14,
  titleRules = {
    { label = "code", rank = 10, contains = { "Claude Code", "Codex", "main", "server", "test", "bug", "fix", "feature", "代码", "测试", "修复" } },
    { label = "docs", rank = 20, contains = { "docs", "README", "PRD", "Word", "contract", "proposal", "文档", "协议", "合同", "方案" } },
    { label = "content", rank = 30, contains = { "skill", "Skill", "article", "script", "copy", "文章", "口播", "写作" } },
    { label = "strategy", rank = 40, contains = { "strategy", "plan", "roadmap", "growth", "战略", "规划", "策略" } },
    { label = "research", rank = 50, contains = { "research", "analysis", "report", "study", "分析", "研究", "报告" } },
  },
}

M.state = {
  sidebar = nil,
  sidebarRows = {},
  sidebarVisible = false,
  refreshTimer = nil,
  sidebarController = nil,
  sidebarScreenFrame = nil,
  expandedWindowId = nil,
  statusByTitle = nil,
  managedWindows = nil,
  lastSourceSpaceByScreen = nil,
  lastDesktopRun = nil,
}

local STATUS_SETTINGS_KEY = "terminalAgents.statusByTitle"
local AGENTS_SPACE_SETTINGS_KEY = "terminalAgents.spaceByScreen"
local SOURCE_SPACE_SETTINGS_KEY = "terminalAgents.sourceSpaceByScreen"

local STATUS_ORDER = { "unknown", "running", "done", "attention" }

local STATUS = {
  unknown = { label = "未知", color = "rgba(255,255,255,.34)" },
  running = { label = "执行中", color = "rgba(82,145,255,1)" },
  done = { label = "完成", color = "rgba(72,210,125,1)" },
  attention = { label = "需处理", color = "rgba(255,174,66,1)" },
}

local GROUP_LABELS = {
  code = "Code",
  docs = "Docs",
  content = "Content",
  strategy = "Strategy",
  research = "Research",
  other = "Other",
}

local GROUP_COLORS = {
  code = { red = 0.29, green = 0.54, blue = 0.95, alpha = 1 },
  docs = { red = 0.95, green = 0.62, blue = 0.25, alpha = 1 },
  content = { red = 0.30, green = 0.73, blue = 0.48, alpha = 1 },
  strategy = { red = 0.70, green = 0.52, blue = 0.95, alpha = 1 },
  research = { red = 0.35, green = 0.72, blue = 0.83, alpha = 1 },
  other = { white = 0.56, alpha = 1 },
}

local COLORS = {
  background = { red = 0.08, green = 0.09, blue = 0.11, alpha = 0.94 },
  border = { white = 1, alpha = 0.12 },
  header = { white = 1, alpha = 0.94 },
  muted = { white = 1, alpha = 0.48 },
  row = { white = 1, alpha = 0.06 },
  rowActive = { red = 0.18, green = 0.37, blue = 0.78, alpha = 0.55 },
  rowHover = { white = 1, alpha = 0.10 },
  text = { white = 1, alpha = 0.88 },
  textActive = { white = 1, alpha = 1 },
}

local function rankTitle(title)
  title = title or ""
  local lowerTitle = string.lower(title)
  for _, rule in ipairs(M.config.titleRules) do
    for _, needle in ipairs(rule.contains) do
      if string.find(lowerTitle, string.lower(needle), 1, true) then
        return rule.rank, rule.label
      end
    end
  end

  return 100, "other"
end

local function containsAny(text, needles)
  local lowerText = string.lower(text or "")
  for _, needle in ipairs(needles or {}) do
    local lowerNeedle = string.lower(tostring(needle or ""))
    if lowerNeedle ~= "" and string.find(lowerText, lowerNeedle, 1, true) then
      return true
    end
  end

  return false
end

local function configuredAppName(app)
  if not app then
    return ""
  end

  return app:name() or ""
end

local function isAlwaysIncludedApp(appName)
  for _, name in ipairs(M.config.includeAllWindowsForApps or {}) do
    if appName == name then
      return true
    end
  end

  return false
end

local function shouldIncludeWindow(appName, title)
  if M.config.includeAllTerminalWindows or isAlwaysIncludedApp(appName) then
    return true
  end

  if containsAny(title, M.config.agentTitleHints) then
    return true
  end

  return false
end

local function gridFor(count)
  if count <= 1 then return 1, 1 end
  if count == 2 then return 2, 1 end
  if count <= 4 then return 2, 2 end
  if count <= 6 then return 3, 2 end
  if count <= 9 then return 3, 3 end
  if count <= 12 then return 4, 3 end
  if count <= 16 then return 4, 4 end

  local cols = math.ceil(math.sqrt(count))
  return cols, math.ceil(count / cols)
end

local function cellsFor(count, frame)
  local cols, rows = gridFor(count)
  local margin = M.config.margin
  local gap = M.config.gap
  local usableW = frame.w - margin * 2 - gap * (cols - 1)
  local usableH = frame.h - margin * 2 - gap * (rows - 1)
  local cellW = math.floor(usableW / cols)
  local cellH = math.floor(usableH / rows)
  local cells = {}

  for i = 1, count do
    local zero = i - 1
    local col = zero % cols
    local row = math.floor(zero / cols)
    cells[i] = {
      x = frame.x + margin + col * (cellW + gap),
      y = frame.y + margin + row * (cellH + gap),
      w = cellW,
      h = cellH,
      col = col + 1,
      row = row + 1,
    }
  end

  return cells, cols, rows
end

local function collectWindows()
  local seen = {}
  local windows = {}

  for _, appName in ipairs(M.config.appNames) do
    local app = hs.application.find(appName)
    if app then
      local actualAppName = configuredAppName(app)
      for _, win in ipairs(app:allWindows()) do
        local id = win:id()
        if id and not seen[id] then
          local subrole = nil
          local frame = nil
          pcall(function()
            subrole = win:subrole()
            frame = win:frame()
          end)

          local manageable = subrole == "AXStandardWindow"
          if manageable and frame and frame.w >= 200 and frame.h >= 120 then
            local title = win:title() or ""
            if shouldIncludeWindow(actualAppName, title) then
              local rank, group = rankTitle(title)
              table.insert(windows, {
                win = win,
                title = title,
                rank = rank,
                group = group,
                appName = actualAppName,
              })
              seen[id] = true
            end
          end
        end
      end
    end
  end

  table.sort(windows, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.title < b.title
  end)

  return windows
end

local function rememberWindows(windows)
  if windows and #windows > 0 then
    M.state.managedWindows = windows
  end
end

local function clearSidebarOnly()
  if M.state.refreshTimer then
    M.state.refreshTimer:stop()
    M.state.refreshTimer = nil
  end
  if M.state.sidebar then
    M.state.sidebar:delete()
    M.state.sidebar = nil
  end
  M.state.sidebarController = nil
  M.state.sidebarRows = {}
  M.state.sidebarVisible = false
  M.state.sidebarScreenFrame = nil
  M.state.expandedWindowId = nil
end

local function usableManagedWindows()
  local managed = M.state.managedWindows or {}
  local usable = {}

  for _, item in ipairs(managed) do
    local ok, id = pcall(function()
      return item.win:id()
    end)
    if ok and id then
      table.insert(usable, item)
    end
  end

  return usable
end

local function currentWindows(options)
  options = options or {}
  local windows = collectWindows()
  if #windows > 0 then
    rememberWindows(windows)
    return windows
  end

  if options.useCache then
    return usableManagedWindows()
  end

  return {}
end

local function displayGroup(group)
  return GROUP_LABELS[group] or group or "其他"
end

local function displayMeta(item)
  if item and item.appName and item.appName ~= "" then
    return string.format("%s · %s", item.appName, displayGroup(item.group))
  end

  return displayGroup(item and item.group)
end

local function groupColor(group)
  return GROUP_COLORS[group] or GROUP_COLORS.other
end

local function cleanTitle(title)
  title = title or ""
  title = title:gsub("^%s*✳%s*", "")
  title = title:gsub("%s+", " ")
  if title == "" then return "Untitled terminal" end
  return title
end

local function truncateText(text, maxChars)
  text = cleanTitle(text)
  if #text <= maxChars then return text end
  return string.sub(text, 1, maxChars - 3) .. "..."
end

local function statusStore()
  if not M.state.statusByTitle then
    M.state.statusByTitle = hs.settings.get(STATUS_SETTINGS_KEY) or {}
  end
  return M.state.statusByTitle
end

local function statusKey(title)
  return cleanTitle(title)
end

local function statusForItem(item)
  local store = statusStore()
  local status = store[statusKey(item.title)]
  if STATUS[status] then
    return status
  end

  return "unknown"
end

local function saveStatusStore()
  hs.settings.set(STATUS_SETTINGS_KEY, M.state.statusByTitle or {})
end

local function notifyStatusDone(title)
  local message = truncateText(title, 42)
  local ok = pcall(function()
    hs.notify.new({
      title = "Terminal agent completed",
      informativeText = message,
      withdrawAfter = 4,
    }):send()
  end)

  if not ok then
    hs.alert.show("完成: " .. message)
  end
end

local function setItemStatus(rowId, nextStatus)
  local item = M.state.sidebarRows[rowId]
  if not item then
    return
  end

  local store = statusStore()
  local key = statusKey(item.title)
  if nextStatus == "unknown" then
    store[key] = nil
  else
    store[key] = nextStatus
  end
  saveStatusStore()

  if nextStatus == "done" then
    notifyStatusDone(item.title)
  end

  M.renderSidebar()
end

local function cycleItemStatus(rowId)
  local item = M.state.sidebarRows[rowId]
  if not item then
    return
  end

  local current = statusForItem(item)
  local currentIndex = 1
  for i, status in ipairs(STATUS_ORDER) do
    if status == current then
      currentIndex = i
      break
    end
  end

  local nextStatus = STATUS_ORDER[(currentIndex % #STATUS_ORDER) + 1]
  setItemStatus(rowId, nextStatus)
end

local function sidebarWidthForFrame(frame)
  return math.min(M.config.sidebarWidth, math.max(280, math.floor(frame.w * 0.24)))
end

local function currentScreenFrame()
  if M.state.sidebarScreenFrame then
    return M.state.sidebarScreenFrame
  end

  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  return screen:frame()
end

local function workAreaFrame(reserveSidebar)
  local frame = currentScreenFrame()
  if reserveSidebar == nil then
    reserveSidebar = M.state.sidebarVisible
  end

  if not reserveSidebar then
    return { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
  end

  local sidebarWidth = sidebarWidthForFrame(frame)
  local gap = M.config.sidebarContentGap
  return {
    x = frame.x + sidebarWidth + gap,
    y = frame.y,
    w = math.max(300, frame.w - sidebarWidth - gap),
    h = frame.h,
  }
end

local function expandedFrame()
  local frame = workAreaFrame(true)
  local margin = M.config.expandMargin
  return {
    x = frame.x + margin,
    y = frame.y + margin,
    w = math.max(320, frame.w - margin * 2),
    h = math.max(240, frame.h - margin * 2),
  }
end

local function bringSidebarToFront()
  if M.state.sidebar then
    M.state.sidebar:bringToFront(true)
  end
end

local function focusSidebarWindow(rowId)
  local item = M.state.sidebarRows[rowId]
  if not item or not item.win then
    hs.alert.show("Terminal agent window is gone")
    return
  end

  local win = item.win
  if win:isMinimized() then
    win:unminimize()
  end

  win:setFrame(expandedFrame(), M.config.expandAnimation)
  M.state.expandedWindowId = win:id()

  local app = win:application()
  if app then
    app:activate(true)
  end
  win:raise()
  win:focus()
  hs.timer.doAfter(M.config.expandAnimation + 0.03, bringSidebarToFront)
end

local function sidebarMetrics(frame, windowCount)
  local width = sidebarWidthForFrame(frame)
  local rowHeight = 42
  local groupHeight = 20
  local titleSize = 13
  local metaSize = 10

  if windowCount >= 14 then
    rowHeight = 36
    groupHeight = 18
    titleSize = 12
    metaSize = 9
  elseif windowCount >= 10 then
    rowHeight = 39
    groupHeight = 19
  end

  return {
    width = width,
    rowHeight = rowHeight,
    groupHeight = groupHeight,
    titleSize = titleSize,
    metaSize = metaSize,
    headerHeight = 56,
    footerHeight = 26,
    padding = 10,
  }
end

local function sidebarFrame()
  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local frame = screen:frame()
  local metrics = sidebarMetrics(frame, 0)
  return {
    x = frame.x,
    y = frame.y,
    w = metrics.width,
    h = frame.h,
  }, frame
end

local function buildSidebarElements(windows, canvasFrame, screenFrame)
  local metrics = sidebarMetrics(screenFrame, #windows)
  local width = canvasFrame.w
  local height = canvasFrame.h
  local padding = metrics.padding
  local elements = {}
  local active = hs.window.frontmostWindow()
  local activeId = active and active:id() or nil

  local function add(element)
    table.insert(elements, element)
  end

  add({
    type = "rectangle",
    action = "fill",
    frame = { x = 0, y = 0, w = width, h = height },
    fillColor = COLORS.background,
  })
  add({
    type = "rectangle",
    action = "stroke",
    frame = { x = width - 1, y = 0, w = 1, h = height },
    strokeColor = COLORS.border,
    strokeWidth = 1,
  })
  add({
    type = "text",
    text = "Terminal agents",
    textFont = ".AppleSystemUIFont",
    textSize = 18,
    textColor = COLORS.header,
    textLineBreak = "truncateTail",
    frame = { x = padding, y = 10, w = width - padding * 2 - 54, h = 24 },
  })
  add({
    type = "text",
    text = string.format("%d windows", #windows),
    textFont = ".AppleSystemUIFont",
    textSize = 11,
    textColor = COLORS.muted,
    frame = { x = padding, y = 34, w = width - padding * 2, h = 16 },
  })
  add({
    id = "refresh",
    type = "rectangle",
    action = "fill",
    frame = { x = width - 58, y = 12, w = 22, h = 22 },
    fillColor = COLORS.row,
    roundedRectRadii = { xRadius = 5, yRadius = 5 },
    trackMouseDown = true,
    trackMouseByBounds = true,
  })
  add({
    id = "refresh",
    type = "text",
    text = "R",
    textFont = ".AppleSystemUIFont",
    textSize = 11,
    textAlignment = "center",
    textColor = COLORS.text,
    frame = { x = width - 58, y = 16, w = 22, h = 16 },
    trackMouseDown = true,
    trackMouseByBounds = true,
  })
  add({
    id = "close",
    type = "rectangle",
    action = "fill",
    frame = { x = width - 30, y = 12, w = 22, h = 22 },
    fillColor = COLORS.row,
    roundedRectRadii = { xRadius = 5, yRadius = 5 },
    trackMouseDown = true,
    trackMouseByBounds = true,
  })
  add({
    id = "close",
    type = "text",
    text = "X",
    textFont = ".AppleSystemUIFont",
    textSize = 11,
    textAlignment = "center",
    textColor = COLORS.text,
    frame = { x = width - 30, y = 16, w = 22, h = 16 },
    trackMouseDown = true,
    trackMouseByBounds = true,
  })

  local y = metrics.headerHeight
  local lastGroup = nil
  M.state.sidebarRows = {}

  for i, item in ipairs(windows) do
    if item.group ~= lastGroup then
      local group = displayGroup(item.group)
      add({
        type = "text",
        text = group,
        textFont = ".AppleSystemUIFont",
        textSize = 10,
        textColor = groupColor(item.group),
        textLineBreak = "truncateTail",
        frame = { x = padding, y = y + 2, w = width - padding * 2, h = metrics.groupHeight - 2 },
      })
      y = y + metrics.groupHeight
      lastGroup = item.group
    end

    if y + metrics.rowHeight + metrics.footerHeight > height then
      local remaining = #windows - i + 1
      add({
        type = "text",
        text = string.format("+ %d more", remaining),
        textFont = ".AppleSystemUIFont",
        textSize = 11,
        textAlignment = "center",
        textColor = COLORS.muted,
        frame = { x = padding, y = y + 6, w = width - padding * 2, h = 18 },
      })
      break
    end

    local rowId = "row-" .. tostring(i)
    local isActive = item.win:id() == activeId
    local rowFill = isActive and COLORS.rowActive or COLORS.row
    M.state.sidebarRows[rowId] = item

    add({
      id = rowId,
      type = "rectangle",
      action = "fill",
      frame = { x = padding, y = y, w = width - padding * 2, h = metrics.rowHeight - 4 },
      fillColor = rowFill,
      roundedRectRadii = { xRadius = 6, yRadius = 6 },
      trackMouseDown = true,
      trackMouseByBounds = true,
    })
    add({
      id = rowId,
      type = "rectangle",
      action = "fill",
      frame = { x = padding, y = y, w = 4, h = metrics.rowHeight - 4 },
      fillColor = groupColor(item.group),
      roundedRectRadii = { xRadius = 2, yRadius = 2 },
      trackMouseDown = true,
      trackMouseByBounds = true,
    })
    add({
      id = rowId,
      type = "text",
      text = tostring(i),
      textFont = ".AppleSystemUIFont",
      textSize = 10,
      textAlignment = "right",
      textColor = isActive and COLORS.textActive or COLORS.muted,
      frame = { x = padding + 8, y = y + 7, w = 20, h = 16 },
      trackMouseDown = true,
      trackMouseByBounds = true,
    })
    add({
      id = rowId,
      type = "text",
      text = truncateText(item.title, 60),
      textFont = ".AppleSystemUIFont",
      textSize = metrics.titleSize,
      textColor = isActive and COLORS.textActive or COLORS.text,
      textLineBreak = "truncateTail",
      frame = { x = padding + 36, y = y + 5, w = width - padding * 2 - 44, h = 18 },
      trackMouseDown = true,
      trackMouseByBounds = true,
    })
    add({
      id = rowId,
      type = "text",
      text = displayMeta(item),
      textFont = ".AppleSystemUIFont",
      textSize = metrics.metaSize,
      textColor = COLORS.muted,
      textLineBreak = "truncateTail",
      frame = { x = padding + 36, y = y + 22, w = width - padding * 2 - 44, h = 14 },
      trackMouseDown = true,
      trackMouseByBounds = true,
    })

    y = y + metrics.rowHeight
  end

  add({
    type = "text",
    text = "⌃⌥⌘S hide  ·  click or ⌃⌥⌘F1-F12 to focus",
    textFont = ".AppleSystemUIFont",
    textSize = 10,
    textAlignment = "center",
    textColor = COLORS.muted,
    textLineBreak = "truncateTail",
    frame = { x = padding, y = height - 22, w = width - padding * 2, h = 16 },
  })

  return elements
end

local function htmlEscape(text)
  text = cleanTitle(text)
  text = text:gsub("&", "&amp;")
  text = text:gsub("<", "&lt;")
  text = text:gsub(">", "&gt;")
  text = text:gsub('"', "&quot;")
  text = text:gsub("'", "&#39;")
  return text
end

local function cssColor(color)
  if color.white then
    local white = math.floor(color.white * 255)
    return string.format("rgba(%d,%d,%d,%.2f)", white, white, white, color.alpha or 1)
  end

  return string.format(
    "rgba(%d,%d,%d,%.2f)",
    math.floor((color.red or 0) * 255),
    math.floor((color.green or 0) * 255),
    math.floor((color.blue or 0) * 255),
    color.alpha or 1
  )
end

local function buildSidebarHTML(windows)
  local active = hs.window.frontmostWindow()
  local activeId = active and active:id() or nil
  local parts = {}

  local function add(line)
    table.insert(parts, line)
  end

  add([[<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
  :root {
    color-scheme: dark;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", sans-serif;
  }
  * { box-sizing: border-box; }
  html, body {
    margin: 0;
    width: 100%;
    height: 100%;
    overflow: hidden;
    background: transparent;
  }
  body {
    color: rgba(255,255,255,.88);
  }
  .shell {
    width: 100vw;
    height: 100vh;
    background: rgba(20,21,27,.94);
    border-right: 1px solid rgba(255,255,255,.12);
    backdrop-filter: blur(18px);
    -webkit-backdrop-filter: blur(18px);
    display: flex;
    flex-direction: column;
  }
  .header {
    height: 56px;
    padding: 10px 10px 6px;
    flex: 0 0 auto;
    position: relative;
  }
  .title {
    font-size: 18px;
    line-height: 24px;
    font-weight: 650;
    color: rgba(255,255,255,.96);
    padding-right: 60px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .count {
    font-size: 11px;
    line-height: 16px;
    color: rgba(255,255,255,.48);
  }
  .actions {
    position: absolute;
    top: 12px;
    right: 8px;
    display: flex;
    gap: 6px;
  }
  button {
    appearance: none;
    -webkit-appearance: none;
    border: 0;
    font: inherit;
    cursor: default;
  }
  .action {
    width: 24px;
    height: 24px;
    border-radius: 6px;
    background: rgba(255,255,255,.10);
    color: rgba(255,255,255,.92);
    text-align: center;
    line-height: 24px;
    font-size: 12px;
    font-weight: 700;
  }
  .list {
    flex: 1 1 auto;
    overflow-y: auto;
    padding: 0 10px 8px;
  }
  .group {
    margin: 8px 0 6px;
    font-size: 11px;
    line-height: 14px;
    font-weight: 700;
  }
  .row {
    display: grid;
    grid-template-columns: 4px 28px minmax(0, 1fr);
    gap: 8px;
    min-height: 40px;
    margin-bottom: 7px;
    padding: 7px 8px 7px 0;
    border-radius: 7px;
    background: rgba(255,255,255,.07);
    color: rgba(255,255,255,.88);
    width: 100%;
    text-align: left;
  }
  .row:hover { background: rgba(255,255,255,.13); }
  .row.active { background: rgba(46,94,199,.56); }
  .stripe {
    width: 4px;
    border-radius: 3px;
  }
  .index {
    text-align: right;
    color: rgba(255,255,255,.54);
    font-size: 12px;
    line-height: 18px;
    font-weight: 650;
    padding-top: 1px;
  }
  .row.active .index { color: rgba(255,255,255,.95); }
  .main { min-width: 0; }
  .name {
    display: block;
    font-size: 13px;
    line-height: 18px;
    font-weight: 580;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .meta {
    display: block;
    font-size: 10px;
    line-height: 13px;
    color: rgba(255,255,255,.48);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .empty {
    padding: 30px 14px;
    color: rgba(255,255,255,.55);
    font-size: 13px;
    line-height: 1.45;
  }
  .footer {
    flex: 0 0 auto;
    height: 25px;
    padding: 4px 10px 7px;
    text-align: center;
    color: rgba(255,255,255,.46);
    font-size: 10px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
</head>
<body>
<div class="shell">
  <div class="header">
    <div class="title">Terminal agents</div>]])
  add(string.format([[    <div class="count">%d windows</div>]], #windows))
  add([[    <div class="actions">
      <button class="action" onclick="sendSidebar('grid')">G</button>
      <button class="action" onclick="sendSidebar('refresh')">R</button>
      <button class="action" onclick="sendSidebar('close')">X</button>
    </div>
  </div>
  <div class="list">]])

  M.state.sidebarRows = {}
  if #windows == 0 then
    add([[    <div class="empty">No terminal agent windows found.</div>]])
  end

  local lastGroup = nil
  for i, item in ipairs(windows) do
    if item.group ~= lastGroup then
      add(string.format(
        [[    <div class="group" style="color:%s">%s</div>]],
        cssColor(groupColor(item.group)),
        htmlEscape(displayGroup(item.group))
      ))
      lastGroup = item.group
    end

    local rowId = "row-" .. tostring(i)
    local isActive = item.win:id() == activeId
    local activeClass = isActive and " active" or ""
    M.state.sidebarRows[rowId] = item

    add(string.format(
      [[    <button class="row%s" onclick="sendSidebar('focus', %d)">
      <span class="stripe" style="background:%s"></span>
      <span class="index">%d</span>
      <span class="main"><span class="name">%s</span><span class="meta">%s</span></span>
    </button>]],
      activeClass,
      i,
      cssColor(groupColor(item.group)),
      i,
      htmlEscape(item.title),
      htmlEscape(displayMeta(item))
    ))
  end

  add([[  </div>
  <div class="footer">Click expands · G restores grid · R refresh</div>
</div>
<script>
function sendSidebar(action, row) {
  try {
    webkit.messageHandlers.ghosttyAgentSidebar.postMessage({ action: action, row: row || 0 });
  } catch (error) {}
}
</script>
</body>
</html>]])

  return table.concat(parts, "\n")
end

function M.renderSidebar()
  local windows = currentWindows()
  local canvasFrame, screenFrame = sidebarFrame()
  M.state.sidebarScreenFrame = screenFrame

  if M.state.sidebar then
    M.state.sidebar:delete()
    M.state.sidebar = nil
  end

  local controller = hs.webview.usercontent.new("ghosttyAgentSidebar")
  controller:setCallback(function(message)
    M.state.lastSidebarMessage = message
    local payload = type(message) == "table" and (message.body or message) or nil
    if type(payload) ~= "table" then return end
    if payload.action == "focus" then
      local rowId = "row-" .. tostring(math.floor(tonumber(payload.row) or 0))
      hs.timer.doAfter(0.05, function()
        focusSidebarWindow(rowId)
      end)
    elseif payload.action == "grid" then
      M.layout({ silent = true, reserveSidebar = true })
    elseif payload.action == "refresh" then
      M.renderSidebar()
    elseif payload.action == "close" then
      M.hideSidebar()
    end
  end)

  local sidebar = hs.webview.new(canvasFrame, {}, controller)
  sidebar:windowStyle({ "borderless", "nonactivating" })
  sidebar:transparent(true)
  sidebar:allowTextEntry(false)
  sidebar:allowGestures(false)
  sidebar:level(hs.drawing.windowLevels.overlay)
  sidebar:behaviorAsLabels({ "moveToActiveSpace", "transient" })
  sidebar:html(buildSidebarHTML(windows), "ghostty-agent://sidebar")
  sidebar:show()
  sidebar:bringToFront(true)

  M.state.sidebar = sidebar
  M.state.sidebarController = controller
  M.state.sidebarVisible = true
end

function M.showSidebar()
  M.renderSidebar()
  M.layout({ silent = true, reserveSidebar = true })
end

function M.hideSidebar()
  clearSidebarOnly()
  M.layout({ silent = true, reserveSidebar = false })
end

function M.toggleSidebar()
  if M.state.sidebarVisible then
    M.hideSidebar()
  else
    M.showSidebar()
  end
end

function M.focusVisibleRow(index)
  if not M.state.sidebarVisible then
    M.showSidebar()
  elseif not M.state.sidebarRows["row-" .. tostring(index)] then
    M.renderSidebar()
  end

  focusSidebarWindow("row-" .. tostring(index))
end

local function screenKey(screen)
  return screen:getUUID() or tostring(screen:id())
end

local function savedAgentsSpaces()
  return hs.settings.get(AGENTS_SPACE_SETTINGS_KEY) or {}
end

local function savedSourceSpaces()
  return hs.settings.get(SOURCE_SPACE_SETTINGS_KEY) or {}
end

local function saveAgentsSpace(screen, spaceId)
  local spaces = savedAgentsSpaces()
  spaces[screenKey(screen)] = spaceId
  hs.settings.set(AGENTS_SPACE_SETTINGS_KEY, spaces)
end

local function saveSourceSpace(screen, spaceId)
  if not spaceId or hs.spaces.spaceType(spaceId) ~= "user" then
    return
  end

  local spaces = savedSourceSpaces()
  spaces[screenKey(screen)] = spaceId
  M.state.lastSourceSpaceByScreen = spaces
  hs.settings.set(SOURCE_SPACE_SETTINGS_KEY, spaces)
end

local function spaceExistsOnScreen(screen, spaceId)
  if not spaceId then return false end

  local spaces = hs.spaces.spacesForScreen(screen) or {}
  for _, candidate in ipairs(spaces) do
    if candidate == spaceId then
      return true
    end
  end

  return false
end

local function createAgentsSpace(screen)
  local before = {}
  for _, spaceId in ipairs(hs.spaces.spacesForScreen(screen) or {}) do
    before[spaceId] = true
  end

  local ok, err = hs.spaces.addSpaceToScreen(screen, false)
  if not ok then
    return nil, err or "failed to create Mission Control space"
  end

  local after = hs.spaces.spacesForScreen(screen) or {}
  for _, spaceId in ipairs(after) do
    if not before[spaceId] then
      saveAgentsSpace(screen, spaceId)
      return spaceId
    end
  end

  local fallback = after[#after]
  if fallback then
    saveAgentsSpace(screen, fallback)
    return fallback
  end

  return nil, "created space but could not resolve its id"
end

local function agentsSpaceForScreen(screen)
  local saved = savedAgentsSpaces()[screenKey(screen)]
  if spaceExistsOnScreen(screen, saved) then
    return saved
  end

  return createAgentsSpace(screen)
end

local function firstUserSourceSpace(screen, targetSpaceId)
  local saved = savedSourceSpaces()[screenKey(screen)]
  if saved and saved ~= targetSpaceId and spaceExistsOnScreen(screen, saved) and hs.spaces.spaceType(saved) == "user" then
    return saved
  end

  for _, spaceId in ipairs(hs.spaces.spacesForScreen(screen) or {}) do
    if spaceId ~= targetSpaceId and hs.spaces.spaceType(spaceId) == "user" then
      return spaceId
    end
  end

  return nil
end

local function moveTerminalWindowsToSpace(windows, spaceId)
  local result = {
    target = spaceId,
    attempted = 0,
    moved = 0,
    already = 0,
    failed = {},
  }

  for _, item in ipairs(windows or usableManagedWindows()) do
    result.attempted = result.attempted + 1

    local okId, winId = pcall(function()
      return item.win:id()
    end)

    if not okId or not winId then
      table.insert(result.failed, { title = item.title, error = "window reference is gone" })
    else
      local spaces = {}
      pcall(function()
        spaces = hs.spaces.windowSpaces(item.win) or {}
      end)

      local alreadyThere = false
      for _, existingSpaceId in ipairs(spaces) do
        if existingSpaceId == spaceId then
          alreadyThere = true
          break
        end
      end

      if alreadyThere then
        result.already = result.already + 1
      else
        pcall(function()
          if item.win:isMinimized() then
            item.win:unminimize()
          end
        end)

        local ok, err = hs.spaces.moveWindowToSpace(winId, spaceId, true)
        if ok then
          local afterSpaces = {}
          pcall(function()
            afterSpaces = hs.spaces.windowSpaces(item.win) or {}
          end)

          local movedThere = false
          for _, afterSpaceId in ipairs(afterSpaces) do
            if afterSpaceId == spaceId then
              movedThere = true
              break
            end
          end

          if movedThere then
            result.moved = result.moved + 1
          else
            table.insert(result.failed, {
              title = item.title,
              id = winId,
              error = "move returned true but window stayed on another space",
            })
          end
        else
          table.insert(result.failed, { title = item.title, id = winId, error = err or "unknown move failure" })
          hs.printf("Terminal agents: moveWindowToSpace failed for %s (%s): %s", tostring(item.title), tostring(winId), tostring(err))
        end
      end
    end
  end

  M.state.lastDesktopRun = result
  return result
end

local function desktopRunSummary(result)
  if not result then
    return "no run"
  end

  return string.format(
    "attempted %d, moved %d, already %d, failed %d",
    result.attempted or 0,
    result.moved or 0,
    result.already or 0,
    #(result.failed or {})
  )
end

local function startAgentsDesktopMove(screen, spaceId, windows)
  rememberWindows(windows)
  saveSourceSpace(screen, hs.spaces.focusedSpace())
  clearSidebarOnly()

  local result = moveTerminalWindowsToSpace(windows, spaceId)
  if (result.moved + result.already) == 0 then
    M.showSidebar()
    hs.alert.show("macOS refused terminal desktop move: " .. desktopRunSummary(result))
    return
  end

  local ok, gotoErr = hs.spaces.gotoSpace(spaceId)
  if not ok then
    hs.alert.show("Cannot enter agents desktop: " .. tostring(gotoErr))
    return
  end

  hs.timer.doAfter(1.0, function()
    local postMove = moveTerminalWindowsToSpace(windows, spaceId)
    M.showSidebar()
    hs.alert.show("Terminal agents desktop: " .. desktopRunSummary(postMove))
  end)
end

local function collectAndEnterAgentsDesktop(screen, spaceId, stage)
  local currentSpace = hs.spaces.focusedSpace()
  local windows = collectWindows()
  if #windows > 0 then
    startAgentsDesktopMove(screen, spaceId, windows)
    return
  end

  local app = nil
  for _, appName in ipairs(M.config.appNames) do
    app = hs.application.find(appName)
    if app then break end
  end
  if app and stage ~= "app" then
    app:activate(true)
    hs.timer.doAfter(0.45, function()
      collectAndEnterAgentsDesktop(screen, spaceId, "app")
    end)
    return
  end

  local sourceSpace = firstUserSourceSpace(screen, spaceId)
  if sourceSpace and sourceSpace ~= currentSpace and stage ~= "source" then
    clearSidebarOnly()
    hs.alert.show("Switching to terminal source desktop")
    hs.spaces.gotoSpace(sourceSpace)
    hs.timer.doAfter(0.9, function()
      collectAndEnterAgentsDesktop(screen, spaceId, "source")
    end)
    return
  end

  hs.alert.show("No terminal agent windows on this desktop. Switch to the agent grid once, then press D.")
end

function M.enterAgentsDesktop()
  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  if not screen then
    hs.alert.show("No screen found")
    return
  end

  local spaceId, err = agentsSpaceForScreen(screen)
  if not spaceId then
    hs.alert.show("Agents desktop failed: " .. tostring(err))
    return
  end

  collectAndEnterAgentsDesktop(screen, spaceId, nil)
end

function M.layout(options)
  options = options or {}
  local windows = currentWindows()
  if #windows == 0 then
    if not options.silent then
      hs.alert.show("No terminal agent windows found")
    end
    return
  end

  local frame = workAreaFrame(options.reserveSidebar)
  local cells, cols, rows = cellsFor(#windows, frame)
  local previousDuration = hs.window.animationDuration
  hs.window.animationDuration = 0

  for i, item in ipairs(windows) do
    local win = item.win
    if win:isMinimized() then
      win:unminimize()
    end
    win:setFrame(cells[i], 0)
  end

  hs.window.animationDuration = previousDuration
  M.state.expandedWindowId = nil
  bringSidebarToFront()

  if not options.silent then
    local suffix = (options.reserveSidebar or M.state.sidebarVisible) and " right workspace" or ""
    hs.alert.show(string.format("Terminal agents: %d windows, %dx%d%s", #windows, cols, rows, suffix))
  end
end

function M.list()
  local windows = currentWindows()
  if #windows == 0 then
    hs.alert.show("No terminal agent windows found")
    return
  end

  local lines = {}
  for i, item in ipairs(windows) do
    table.insert(lines, string.format("%d. [%s] %s", i, displayMeta(item), cleanTitle(item.title)))
  end

  hs.alert.show(table.concat(lines, "\n"), 5)
end

function M.windowSummary()
  local windows = currentWindows()
  if #windows == 0 then
    return "No terminal agent windows found on the current desktop."
  end

  local lines = { string.format("Terminal agent windows: %d", #windows) }
  for i, item in ipairs(windows) do
    table.insert(lines, string.format("%2d. [%s] %s", i, displayMeta(item), cleanTitle(item.title)))
  end

  return table.concat(lines, "\n")
end

function M.doctor()
  local windows = currentWindows()
  local runningApps = {}
  local seenApps = {}
  for _, appName in ipairs(M.config.appNames) do
    local app = hs.application.find(appName)
    if app then
      local name = configuredAppName(app)
      if name ~= "" and not seenApps[name] then
        table.insert(runningApps, name)
        seenApps[name] = true
      end
    end
  end

  local runningAppText = #runningApps > 0 and table.concat(runningApps, ", ") or "not found"
  local accessibility = "unknown"
  local okAccessibility, accessibilityEnabled = pcall(function()
    return hs.accessibilityState()
  end)

  if okAccessibility then
    accessibility = accessibilityEnabled and "enabled" or "disabled"
  end

  local lines = {
    "Terminal Agents Layout doctor",
    string.format("- Hammerspoon: running"),
    string.format("- Accessibility: %s", accessibility),
    string.format("- Supported terminal apps running: %s", runningAppText),
    string.format("- Terminal agent windows on current desktop: %d", #windows),
    string.format("- Sidebar: %s", M.state.sidebarVisible and "visible" or "hidden"),
  }

  if #windows == 0 then
    table.insert(lines, "")
    table.insert(lines, "Open one or more Claude Code / Codex terminal windows on this desktop, then run:")
    table.insert(lines, "  ghostty-agents sidebar")
    table.insert(lines, "  ghostty-agents grid")
    table.insert(lines, "")
    table.insert(lines, "If you use Terminal/iTerm/Warp and nothing appears, set the terminal title first:")
    table.insert(lines, "  printf '\\033]0;Claude Code - my-project\\007'")
  else
    table.insert(lines, "")
    table.insert(lines, "Try:")
    table.insert(lines, "  ghostty-agents sidebar")
    table.insert(lines, "  ghostty-agents grid")
    table.insert(lines, "  ghostty-agents focus 1")
  end

  return table.concat(lines, "\n")
end

function M.cliHelp()
  return table.concat({
    "Usage: ghostty-agents <command>",
    "",
    "Commands:",
    "  grid       Arrange terminal agent windows into a grid",
    "  sidebar    Toggle the left agents sidebar",
    "  show       Show the left agents sidebar",
    "  hide       Hide the left agents sidebar",
    "  list       Print terminal agent windows on the current desktop",
    "  focus N    Focus sidebar row N",
    "  title TEXT Set the current terminal title for matching",
    "  desktop    Experimental: try to enter the agents desktop",
    "  doctor     Check Hammerspoon, terminal apps, and next steps",
    "  help       Show this help",
  }, "\n")
end

function M.cli(command, arg)
  command = command or "help"

  if command == "grid" or command == "layout" then
    local windows = currentWindows()
    M.layout({ silent = true })
    return string.format("Arranged %d terminal agent window(s).", #windows)
  elseif command == "sidebar" or command == "toggle" then
    M.toggleSidebar()
    return M.state.sidebarVisible and "Sidebar shown." or "Sidebar hidden."
  elseif command == "show" then
    M.showSidebar()
    return "Sidebar shown."
  elseif command == "hide" then
    M.hideSidebar()
    return "Sidebar hidden."
  elseif command == "list" then
    return M.windowSummary()
  elseif command == "focus" then
    local index = tonumber(arg)
    if not index or index < 1 then
      return "Usage: ghostty-agents focus <number>"
    end
    M.focusVisibleRow(math.floor(index))
    return string.format("Focused terminal agent %d.", math.floor(index))
  elseif command == "desktop" then
    M.enterAgentsDesktop()
    return "Started agents desktop flow."
  elseif command == "doctor" then
    return M.doctor()
  elseif command == "help" or command == "--help" or command == "-h" then
    return M.cliHelp()
  end

  return "Unknown command: " .. tostring(command) .. "\n\n" .. M.cliHelp()
end

function M.bindHotkeys()
  hs.hotkey.bind(M.config.hotkey[1], M.config.hotkey[2], M.layout)
  hs.hotkey.bind(M.config.listHotkey[1], M.config.listHotkey[2], M.list)
  hs.hotkey.bind(M.config.sidebarHotkey[1], M.config.sidebarHotkey[2], M.toggleSidebar)
  hs.hotkey.bind(M.config.desktopHotkey[1], M.config.desktopHotkey[2], M.enterAgentsDesktop)

  for i = 1, 12 do
    hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "F" .. tostring(i), function()
      M.focusVisibleRow(i)
    end)
  end
end

return M
