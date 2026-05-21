--- === StacklineAerospace ===
---
--- Stack indicators for AeroSpace accordion containers.
--- Inspired by stackline (yabai-only); driven instead by the `aerospace` CLI.

local obj = {}
obj.__index = obj

obj.name = "StacklineAerospace"
obj.version = "0.2.0"
obj.license = "MIT"

-- Config (override after hs.loadSpoon, before :start())
obj.aerospace            = "/opt/homebrew/bin/aerospace"
obj.pollInterval         = 2.0  -- fallback poll, seconds (window events drive most updates)
obj.debounceMs           = 60   -- coalesce bursts of window events
obj.pillThickness        = 3    -- short dimension of each pill
obj.pillLength           = 14   -- long dimension of each pill
obj.pillGap              = 4    -- gap between pills
obj.cornerInset          = 10   -- offset of the backdrop from the focused window's corner
obj.edgeMargin           = 4    -- minimum space required between the indicator and the window edge
obj.backdropPadding      = 5    -- padding between the pills and the backdrop edge
obj.backdropCornerRadius = 4
obj.backdropColor        = { red = 0.00, green = 0.00, blue = 0.00, alpha = 0.40 }
obj.focusedColor         = { red = 0.95, green = 0.95, blue = 0.95, alpha = 1.00 }
obj.unfocusedColor       = { red = 0.95, green = 0.95, blue = 0.95, alpha = 0.35 }

-- Internal state
obj._canvas      = nil
obj._timer       = nil
obj._wf          = nil
obj._debounce    = nil
obj._listTask    = nil
obj._focusedTask = nil
obj._inFlight    = false
obj._pending     = false
obj._lastKey     = nil

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function parseList(out)
  local rows = {}
  for line in string.gmatch(out or "", "[^\n]+") do
    local cols = {}
    for col in string.gmatch(line, "([^|]+)") do
      table.insert(cols, trim(col))
    end
    if #cols >= 3 then
      table.insert(rows, { id = cols[1], app = cols[2], layout = cols[3] })
    end
  end
  return rows
end

local function sortByVisualOrder(stack)
  local entries = {}
  for _, w in ipairs(stack.windows) do
    local hw = hs.window.get(tonumber(w.id))
    local x, y = 0, 0
    if hw then
      local f = hw:frame()
      x, y = f.x, f.y
    end
    table.insert(entries, { w = w, x = x, y = y })
  end
  if stack.layout == "v_accordion" then
    table.sort(entries, function(a, b) return a.y < b.y end)
  else
    table.sort(entries, function(a, b) return a.x < b.x end)
  end
  local sorted = {}
  for _, e in ipairs(entries) do table.insert(sorted, e.w) end
  stack.windows = sorted
end

local function groupStacks(rows)
  local stacks, cur = {}, nil
  for _, w in ipairs(rows) do
    local accordion = (w.layout == "h_accordion") or (w.layout == "v_accordion")
    if accordion then
      if cur and cur.layout == w.layout then
        table.insert(cur.windows, w)
      else
        cur = { layout = w.layout, windows = { w } }
        table.insert(stacks, cur)
      end
    else
      cur = nil
    end
  end
  local out = {}
  for _, s in ipairs(stacks) do
    if #s.windows >= 2 then
      sortByVisualOrder(s)
      table.insert(out, s)
    end
  end
  return out
end

local function findStackOf(stacks, id)
  for _, s in ipairs(stacks) do
    for i, w in ipairs(s.windows) do
      if w.id == id then return s, i end
    end
  end
  return nil, nil
end

local function buildKey(focused, stack, idx)
  local key = (focused or "") .. "#"
  if not stack then return key end
  key = key .. stack.layout .. ":" .. tostring(idx) .. "/"
  for _, w in ipairs(stack.windows) do key = key .. w.id .. "," end
  return key
end

function obj:_render(stack, idx)
  if self._canvas then self._canvas:delete(); self._canvas = nil end
  if not stack then return end

  local win = hs.window.focusedWindow()
  if not win then return end
  local f = win:frame()
  local visible = win:screen():frame()

  local n        = #stack.windows
  local vertical = (stack.layout == "v_accordion")
  local thick    = self.pillThickness
  local len      = self.pillLength
  local gap      = self.pillGap
  local pad      = self.backdropPadding

  local pillW = vertical and thick or len
  local pillH = vertical and len or thick
  local stripW = vertical and pillW or (n * pillW + (n - 1) * gap)
  local stripH = vertical and (n * pillH + (n - 1) * gap) or pillH

  local backdropW = stripW + 2 * pad
  local backdropH = stripH + 2 * pad

  local backdropX = f.x + self.cornerInset
  local backdropY = f.y + self.cornerInset
  if vertical then
    local room = f.x - visible.x
    if room >= backdropW + self.edgeMargin then
      backdropX = visible.x + (room - backdropW) / 2
    end
  else
    local room = f.y - visible.y
    if room >= backdropH + self.edgeMargin then
      backdropY = visible.y + (room - backdropH) / 2
    end
  end

  self._canvas = hs.canvas.new({ x = backdropX, y = backdropY, w = backdropW, h = backdropH })
  self._canvas:appendElements({
    type             = "rectangle",
    action           = "fill",
    fillColor        = self.backdropColor,
    roundedRectRadii = { xRadius = self.backdropCornerRadius, yRadius = self.backdropCornerRadius },
    frame            = { x = 0, y = 0, w = backdropW, h = backdropH },
  })

  for i = 1, n do
    local color = (i == idx) and self.focusedColor or self.unfocusedColor
    local px = vertical and pad or pad + (i - 1) * (pillW + gap)
    local py = vertical and pad + (i - 1) * (pillH + gap) or pad
    self._canvas:appendElements({
      type             = "rectangle",
      action           = "fill",
      fillColor        = color,
      roundedRectRadii = { xRadius = thick / 2, yRadius = thick / 2 },
      frame            = { x = px, y = py, w = pillW, h = pillH },
    })
  end

  self._canvas:level(hs.canvas.windowLevels.overlay)
  self._canvas:show()
end

function obj:_apply(rows, focused)
  local stacks     = groupStacks(rows)
  local stack, idx = findStackOf(stacks, focused)
  local key        = buildKey(focused, stack, idx)
  if key == self._lastKey then return end
  self._lastKey = key
  self:_render(stack, idx)
end

function obj:_runQuery()
  if self._inFlight then
    self._pending = true
    return
  end
  self._inFlight = true

  local rows, focused, gotList, gotFocused = nil, nil, false, false
  local function maybeApply()
    if not (gotList and gotFocused) then return end
    self._inFlight = false
    self:_apply(rows, focused)
    if self._pending then
      self._pending = false
      self:_schedule()
    end
  end

  local fmt = "%{window-id}|%{app-name}|%{window-parent-container-layout}"
  self._listTask = hs.task.new(self.aerospace, function(_, stdout, _)
    rows = parseList(stdout); gotList = true; maybeApply()
  end, { "list-windows", "--workspace", "focused", "--format", fmt })
  self._focusedTask = hs.task.new(self.aerospace, function(_, stdout, _)
    focused = trim(stdout or ""); gotFocused = true; maybeApply()
  end, { "list-windows", "--focused", "--format", "%{window-id}" })
  self._listTask:start()
  self._focusedTask:start()
end

function obj:_schedule()
  if not self._debounce then
    self._debounce = hs.timer.delayed.new(self.debounceMs / 1000, function()
      self:_runQuery()
    end)
  end
  self._debounce:start()
end

function obj:start()
  self:stop()
  self._timer = hs.timer.doEvery(self.pollInterval, function() self:_schedule() end)
  self._wf = hs.window.filter.new()
  self._wf:subscribe({
    hs.window.filter.windowFocused,
    hs.window.filter.windowUnfocused,
    hs.window.filter.windowCreated,
    hs.window.filter.windowDestroyed,
  }, function() self:_schedule() end)
  self:_schedule()
  return self
end

function obj:stop()
  if self._timer       then self._timer:stop();        self._timer       = nil end
  if self._debounce    then self._debounce:stop();     self._debounce    = nil end
  if self._wf          then self._wf:unsubscribeAll(); self._wf          = nil end
  if self._canvas      then self._canvas:delete();     self._canvas      = nil end
  if self._listTask    then pcall(self._listTask.terminate, self._listTask);    self._listTask    = nil end
  if self._focusedTask then pcall(self._focusedTask.terminate, self._focusedTask); self._focusedTask = nil end
  self._inFlight, self._pending, self._lastKey = false, false, nil
  return self
end

return obj
