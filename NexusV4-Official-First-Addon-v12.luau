-- NexusV4 overlays and utility additions, adapted from the supplied source.
-- Restores old framework's Keybinds plus the 3 overlays defined in the uploaded source:
-- Bed Defense, Hit Accuracy, Inventory Overlay.
-- Newer CatVape already provides Text GUI, Target Info, and Spotify overlays.
-- Run AFTER the newer shared.Cat interface has initialized.
-- Adds no HitregAdjuster or attack-request code.

if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local lp = Players.LocalPlayer or Players.PlayerAdded:Wait()
local env = (type(getgenv) == "function" and getgenv()) or _G
local previous = env.__CVRestoredOverlays
if type(previous) == "table" and previous.alive and shared and shared.Cat
    and previous.revision == 12
    and previous.ui == (shared.Cat.Context or (shared.Cat.Cat and shared.Cat.Cat.Ui)) then
    warn("[Nexus overlays] Already installed in this UI")
    return
end
if type(previous) == "table" and type(previous.Destroy) == "function" then pcall(previous.Destroy) end

local life = {alive = true, revision = 12, connections = {}, objects = {}, overlays = {}}
env.__CVRestoredOverlays = life
function life.Destroy()
    if not life.alive then return end
    life.alive = false
    if life.autoBlockCleanup then pcall(life.autoBlockCleanup) end
    if life.fovCleanup then pcall(life.fovCleanup) end
    if life.potatoCleanup then pcall(life.potatoCleanup) end
    for _, connection in ipairs(life.connections) do pcall(function() connection:Disconnect() end) end
    for _, object in ipairs(life.objects) do pcall(function() object:Destroy() end) end
    table.clear(life.connections)
    table.clear(life.objects)
    if env.__CVRestoredOverlays == life then env.__CVRestoredOverlays = nil end
end
local function track(thing)
    table.insert(life.objects, thing)
    return thing
end
local function connect(signal, callback)
    local result = signal:Connect(callback)
    table.insert(life.connections, result)
    return result
end
local function warnUser(message)
    warn("[Nexus overlays] " .. tostring(message))
    pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "NexusV4", Text = tostring(message), Duration = 5
    }) end)
end

local cat, ui
for _ = 1, 240 do
    if not life.alive then return end
    local library = shared and shared.Cat
    if type(library) == "table" and type(library.Cat) == "table"
        and type(library.Cat.CreateOverlay) == "function" then
        local potentialUi = library.Context or library.Cat.Ui
        if type(potentialUi) == "table" and type(potentialUi.Modules) == "table"
            and potentialUi.Gui and potentialUi.Scaled then
            cat, ui = library.Cat, potentialUi
            break
        end
    end
    task.wait(0.125)
end
if not cat or not ui then
    warnUser("Nexus interface unavailable; load Nexus first")
    life.Destroy()
    return
end
life.ui = ui
pcall(function() cat:Clean(life.Destroy) end)

local function make(className, properties, parent)
    local result = Instance.new(className)
    for key, value in pairs(properties or {}) do result[key] = value end
    result.Parent = parent
    return result
end
local function corner(parent, radius)
    return make("UICorner", {CornerRadius = UDim.new(0, radius or 5)}, parent)
end
local function label(parent, value, x, y, w, h, size, align)
    return make("TextLabel", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = tostring(value), TextColor3 = Color3.fromRGB(232, 244, 253),
        Font = Enum.Font.GothamMedium, TextSize = size or 12,
        TextXAlignment = align or Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h)
    }, parent)
end
local function panel(overlay, width, height)
    local frame = track(make("Frame", {
        BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(12, 20, 30),
        BackgroundTransparency = 0.35, Size = UDim2.fromOffset(width, height),
        Name = "RestoredOverlayContent"
    }, overlay.Children))
    corner(frame, 7)
    return frame
end
local function addOverlay(name, icon, width, height)
    -- Native UI manages its own menu, pin button and profile saves.
    if ui.Scaled:FindFirstChild(name .. "Overlay") then return nil end
    local ok, result = pcall(function()
        return cat:CreateOverlay({
            Name = name, Icon = icon, Size = UDim2.fromOffset(14, 14),
            Position = UDim2.fromOffset(12, 13), CategorySize = math.max(220, math.min(width, 360))
        })
    end)
    if not ok or not result or not result.Children or not result.Button then
        warn("[Nexus overlays] " .. name .. ": " .. tostring(result))
        return nil
    end
    life.overlays[name] = result
    local frame = panel(result, width, height)
    return result, frame
end
local function createToggle(overlay, name, default, callback)
    return overlay:CreateToggle({Name = name, Default = default, Function = callback or function() end})
end
local function createSlider(overlay, name, low, high, default, callback)
    return overlay:CreateSlider({Name = name, Min = low, Max = high,
        Default = default, Function = callback or function() end})
end

-- Keybinds: auto-size to visible labels and row count; never reorder on activation.
-- Width fits the longest assigned binding/name and height grows until scrolling is needed.
do
    local overlay, frame = addOverlay("Keybinds", "bind", 208, 120)
    if overlay then
        local state = {showDisabled = true, showUnbound = false, hideMenu = false,
            textSize = 12, textOpacity = 0, panelTransparency = 0.55, maxRows = 30}
        createToggle(overlay, "Show disabled", true, function(v) state.showDisabled = v end)
        createToggle(overlay, "Show unbound", false, function(v) state.showUnbound = v end)
        createToggle(overlay, "Hide while menu open", false, function(v) state.hideMenu = v end)
        createSlider(overlay, "Text opacity", 0, 50, 0, function(v) state.textOpacity = v / 100 end)
        createSlider(overlay, "Panel transparency", 20, 95, 55, function(v) state.panelTransparency = v / 100 end)
        createSlider(overlay, "Text size", 10, 18, 12, function(v) state.textSize = v end)
        createSlider(overlay, "Max rows", 3, 30, 30, function(v) state.maxRows = math.floor(v) end)

        frame.ClipsDescendants = true
        local header = label(frame, "Keybinds", 11, 7, 190, 22, 14)
        header.Font = Enum.Font.GothamBold
        local viewport = make("ScrollingFrame", {
            Name = "KeybindRows", BorderSizePixel = 0, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(9, 32), Size = UDim2.new(1, -18, 1, -39),
            ScrollBarThickness = 2, ScrollingDirection = Enum.ScrollingDirection.Y,
            CanvasSize = UDim2.fromOffset(0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.None,
            ClipsDescendants = true
        }, frame)
        local rows = {}
        for index = 1, 30 do
            local left = label(viewport, "", 3, 0, 43, 20, 11)
            local right = label(viewport, "", 49, 0, 142, 20, 12)
            rows[index] = {left = left, right = right}
        end
        local currentLayoutSignature
        local rowHeight = 21
        local panelWidth, panelHeight = 208, 120
        local function measure(value, size)
            local ok, bounds = pcall(TextService.GetTextSize, TextService,
                tostring(value), size, Enum.Font.GothamMedium, Vector2.new(2000, 36))
            if ok and typeof(bounds) == "Vector2" then return math.ceil(bounds.X) end
            return math.ceil(#tostring(value) * size * 0.62)
        end
        local function keyText(module)
            local bind = module and module.Bind
            if type(bind) ~= "table" or type(bind.Keys) ~= "table" then return "" end
            local keys = {}
            for _, key in ipairs(bind.Keys) do
                if type(key) == "string" and key ~= "" then
                    keys[#keys + 1] = key:gsub("Right", "R"):gsub("Left", "L")
                end
            end
            return table.concat(keys, "+")
        end
        local function render()
            if not overlay.Button.Enabled then return end
            frame.Visible = not (state.hideMenu and ui.Click and ui.Click.Visible)
            if not frame.Visible then return end
            local entries = {}
            for name, mod in pairs(ui.Modules) do
                if name ~= "Scaffold" and type(mod) == "table" and not mod.Removed
                    and (state.showDisabled or mod.Enabled) then
                    local keys = keyText(mod)
                    if keys ~= "" or state.showUnbound then
                        entries[#entries + 1] = {name = tostring(name), keys = keys, enabled = mod.Enabled}
                    end
                end
            end
            -- Enabled changes affect ONLY tint, never ordering or row geometry.
            table.sort(entries, function(a, b)
                local x, y = a.name:lower(), b.name:lower()
                return x == y and a.name < b.name or x < y
            end)
            local count = math.min(#entries, state.maxRows, #rows)
            local accent = Color3.fromRGB(115, 192, 245)
            pcall(function() accent = ui:Color(0) end)
            frame.BackgroundColor3 = Color3.fromRGB(26, 29, 48):Lerp(accent, 0.22)
            frame.BackgroundTransparency = state.panelTransparency
            header.TextColor3 = Color3.fromRGB(242, 244, 255)
            header.TextTransparency = state.textOpacity

            -- Re-measure only when the *text* or chosen font size changes.
            -- Module activation is intentionally omitted from this signature.
            local signature = {tostring(state.textSize), tostring(count)}
            for i = 1, count do
                signature[#signature + 1] = entries[i].keys .. "\1" .. entries[i].name
            end
            local layoutSignature = table.concat(signature, "\2")
            if layoutSignature ~= currentLayoutSignature then
                currentLayoutSignature = layoutSignature
                rowHeight = math.max(20, state.textSize + 7)
                local maxKey, maxName = 20, measure("Keybinds", 14)
                for i = 1, count do
                    local entry = entries[i]
                    maxKey = math.max(maxKey, measure(entry.keys ~= "" and entry.keys or "--", state.textSize - 1))
                    maxName = math.max(maxName, measure(entry.name, state.textSize))
                end
                local leftWidth = math.clamp(maxKey + 10, 36, 105)
                panelWidth = math.clamp(math.ceil(9 + 3 + leftWidth + 7 + maxName + 18), 195, 365)
                -- The box follows the content, but cannot fill the entire screen.
                -- Rows beyond the cap stay scrollable, never stretch the whole UI.
                panelHeight = math.clamp(39 + count * rowHeight, 59, 330)
                frame.Size = UDim2.fromOffset(panelWidth, panelHeight)
                overlay.Children.Size = UDim2.new(1, 0, 0, panelHeight)
                header.Size = UDim2.fromOffset(panelWidth - 20, 22)
                for i, row in ipairs(rows) do
                    local y = (i - 1) * rowHeight
                    row.left.Position = UDim2.fromOffset(3, y)
                    row.left.Size = UDim2.fromOffset(leftWidth, rowHeight - 1)
                    row.right.Position = UDim2.fromOffset(leftWidth + 10, y)
                    row.right.Size = UDim2.fromOffset(panelWidth - leftWidth - 28, rowHeight - 1)
                end
                viewport.CanvasSize = UDim2.fromOffset(0, count * rowHeight)
            end
            if overlay.Object.Size.X.Offset ~= panelWidth then
                -- Keep the framework's own expanded/collapsed height intact.
                overlay.Object.Size = UDim2.fromOffset(panelWidth, overlay.Object.Size.Y.Offset)
            end
            for i, row in ipairs(rows) do
                local visible = i <= count
                row.left.Visible, row.right.Visible = visible, visible
                if visible then
                    local entry = entries[i]
                    row.left.Text, row.right.Text = entry.keys ~= "" and entry.keys or "--", entry.name
                    row.left.TextSize = state.textSize - 1
                    row.right.TextSize = state.textSize
                    row.left.TextColor3 = entry.enabled and accent or Color3.fromRGB(123, 129, 152)
                    row.right.TextColor3 = entry.enabled and Color3.fromRGB(238, 241, 255)
                        or Color3.fromRGB(143, 148, 172)
                    row.left.TextTransparency = state.textOpacity + (entry.enabled and 0 or 0.16)
                    row.right.TextTransparency = state.textOpacity + (entry.enabled and 0 or 0.16)
                end
            end
        end
        local pos = ui.Data and ui.Data["Overlays/Keybinds#Window"]
        local function dockNearMain()
            local main = shared.Cat and shared.Cat.Window and shared.Cat.Window.Object
            local scale = (ui.Scale and ui.Scale.Scale) or 1
            if type(scale) ~= "number" or scale <= 0 then scale = 1 end
            local parent = overlay.Object.Parent
            local available = parent and parent.AbsoluteSize or Vector2.new(1280, 720)
            local x, y = 240, 85
            if main and main.Parent then
                x = (main.AbsolutePosition.X + main.AbsoluteSize.X + 12
                    - (parent and parent.AbsolutePosition.X or 0)) / scale
                y = (main.AbsolutePosition.Y + 16
                    - (parent and parent.AbsolutePosition.Y or 0)) / scale
            end
            local maxX = math.max(8, available.X / scale - (frame.Size.X.Offset + 12))
            local maxY = math.max(8, available.Y / scale - (frame.Size.Y.Offset + 46))
            overlay.Object.Position = UDim2.fromOffset(
                math.floor(math.clamp(x, 8, maxX)), math.floor(math.clamp(y, 8, maxY)))
        end
        local invalidLegacyPosition = type(pos) ~= "table" or type(pos.X) ~= "number"
            or type(pos.Y) ~= "number" or pos.X < 0 or pos.Y < 0
        if invalidLegacyPosition then
            task.defer(function()
                if life.alive and overlay.Object.Parent then
                    dockNearMain()
                    pcall(function() ui:Save() end)
                end
            end)
        end
        if type(pos) ~= "table" then
            pcall(function() overlay:Pin(true) end)
            pcall(function() overlay.Button:Toggle(true) end)
        end
        life.keybindRefresh = render
        render()
    end
end

-- Bed Defense from the old source: a lightweight top-down defensive-block view.
-- The newer CatVape build does not expose the old viewer's private block engine.
do
    local overlay, frame = addOverlay("Bed Defense", "legit_bedalarm", 226, 204)
    if overlay then
        local state = {target = "Nearest", maxLayers = 6, showBed = true, transparent = 0.38}
        overlay:CreateDropdown({Name = "Bed", List = {"Nearest", "Crosshair"}, Default = "Nearest",
            Function = function(v) state.target = v end})
        createSlider(overlay, "Max layers", 1, 10, 6, function(v) state.maxLayers = math.floor(v) end)
        createToggle(overlay, "Show bed", true, function(v) state.showBed = v end)
        createSlider(overlay, "Transparency", 0, 95, 38, function(v) state.transparent = v / 100 end)
        local caption = label(frame, "SEARCHING FOR ENEMY BED", 9, 7, 207, 18, 11)
        local sub = label(frame, "", 9, 181, 209, 19, 10)
        local grid = make("Frame", {BackgroundTransparency = 1,
            Position = UDim2.fromOffset(40, 30), Size = UDim2.fromOffset(145, 145)}, frame)
        local cells = {}
        for z = -5, 5 do
            for x = -5, 5 do
                local square = make("Frame", {
                    BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(25, 38, 51),
                    BackgroundTransparency = 0.88, Size = UDim2.fromOffset(12, 12),
                    Position = UDim2.fromOffset((x + 5) * 13, (z + 5) * 13)
                }, grid)
                cells[#cells + 1] = {x = x, z = z, object = square}
            end
        end
        local function rootOf(player)
            local model = player.Character
            return model and model:FindFirstChild("HumanoidRootPart")
        end
        local function enemyBed()
            local me = rootOf(lp)
            if not me then return nil end
            local found = {}
            local seen = {}
            for _, tag in ipairs({"bed", "Bed"}) do
                for _, bed in ipairs(CollectionService:GetTagged(tag)) do
                    if bed.Parent and not seen[bed] then
                        seen[bed] = true
                        local owner = bed:GetAttribute("Team") or bed:GetAttribute("TeamId")
                        local sameTeam = owner ~= nil and (tostring(owner) == tostring(lp:GetAttribute("Team"))
                            or lp.Team and tostring(owner) == lp.Team.Name)
                        if not sameTeam then
                            local ok, position = pcall(function()
                                return bed:IsA("Model") and bed:GetPivot().Position or bed.Position
                            end)
                            if ok and typeof(position) == "Vector3" then
                                local distance = (position - me.Position).Magnitude
                                local score = distance
                                if state.target == "Crosshair" and workspace.CurrentCamera then
                                    local look = workspace.CurrentCamera.CFrame.LookVector
                                    local offset = position - workspace.CurrentCamera.CFrame.Position
                                    if offset.Magnitude > 0 then score = -look:Dot(offset.Unit) * 1000 + distance * 0.01 end
                                end
                                found[#found + 1] = {bed = bed, position = position, distance = distance, score = score}
                            end
                        end
                    end
                end
            end
            table.sort(found, function(a, b) return a.score < b.score end)
            return found[1]
        end
        local colors = {
            wool = Color3.fromRGB(216, 124, 177), wood = Color3.fromRGB(170, 113, 72),
            stone = Color3.fromRGB(133, 150, 168), obsidian = Color3.fromRGB(88, 66, 117),
            glass = Color3.fromRGB(96, 191, 209), bed = Color3.fromRGB(87, 234, 170)
        }
        local function blockType(part)
            local name = tostring(part:GetAttribute("BlockType") or part:GetAttribute("blockType") or part.Name):lower()
            for _, key in ipairs({"obsidian", "wool", "glass", "wood", "stone", "bed"}) do
                if name:find(key, 1, true) then return key end
            end
            if name:find("plank", 1, true) then return "wood" end
            if name:find("brick", 1, true) or name:find("clay", 1, true) then return "stone" end
            return nil
        end
        local function render()
            if not overlay.Button.Enabled then return end
            local target = enemyBed()
            frame.BackgroundTransparency = state.transparent
            for _, cell in ipairs(cells) do
                cell.object.BackgroundTransparency = 0.88
                cell.object.BackgroundColor3 = Color3.fromRGB(25, 38, 51)
            end
            if not target then
                caption.Text = "NO ENEMY BED FOUND"
                sub.Text = "Move near a detectable bed"
                return
            end
            caption.Text = string.format("BED  •  %d STUDS", math.floor(target.distance))
            local center = target.position
            local params = OverlapParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            local characters = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then characters[#characters + 1] = player.Character end
            end
            params.FilterDescendantsInstances = characters
            params.MaxParts = 256
            local ok, candidates = pcall(function()
                return workspace:GetPartBoundsInBox(CFrame.new(center), Vector3.new(33, state.maxLayers * 3, 33), params)
            end)
            local map = {}
            local count = 0
            if ok and #candidates < 256 then
                for _, part in ipairs(candidates) do
                    if part:IsA("BasePart") then
                        local material = blockType(part)
                        if material and (part.Position - center).Magnitude <= 25 then
                            local x = math.round((part.Position.X - center.X) / 3)
                            local z = math.round((part.Position.Z - center.Z) / 3)
                            if math.abs(x) <= 5 and math.abs(z) <= 5 then
                                map[x .. ":" .. z] = colors[material]
                                count += 1
                            end
                        end
                    end
                end
            end
            if state.showBed then map["0:0"] = colors.bed end
            for _, cell in ipairs(cells) do
                local color = map[cell.x .. ":" .. cell.z]
                if color then cell.object.BackgroundTransparency = 0.03; cell.object.BackgroundColor3 = color end
            end
            sub.Text = count > 0 and string.format("%d nearby defense parts  •  TOP VIEW", count)
                or "Defense blocks not replicated / found"
        end
        life.bedRefresh = render
    end
end

-- Hit Accuracy: reads the original CatVape hitchance telemetry when available.
-- A live newer build lacking that telemetry displays unavailable instead of fake percentages.
do
    local overlay, frame = addOverlay("Hit Accuracy", "aim", 212, 125)
    if overlay then
        local state = {hideUnused = true, showColor = true, transparency = 0.42}
        createToggle(overlay, "Hide unused", true, function(v) state.hideUnused = v end)
        createToggle(overlay, "Color the number", true, function(v) state.showColor = v end)
        createSlider(overlay, "Transparency", 0, 95, 42, function(v) state.transparency = v / 100 end)
        local sources = {"ProjectileAura", "ProjectileAimbot", "SilentAim", "TerraAimbot"}
        local rows = {}
        for i, name in ipairs(sources) do
            local title = label(frame, name, 9, 7 + (i - 1) * 25, 146, 20, 11)
            local percent = label(frame, "--", 155, 7 + (i - 1) * 25, 48, 20, 11, Enum.TextXAlignment.Right)
            rows[i] = {title = title, percent = percent}
        end
        local empty = label(frame, "Waiting for hit-chance telemetry", 10, 9, 192, 22, 11)
        local function render()
            if not overlay.Button.Enabled then return end
            frame.BackgroundTransparency = state.transparency
            local older = shared and shared.vape
            local store = older and older.Libraries and older.Libraries.store
            local chances = store and store.hitchance
            local count = 0
            for i, name in ipairs(sources) do
                local item = type(chances) == "table" and chances[name]
                local active = type(item) == "table" and type(item.Value) == "number"
                    and type(item.Clock) == "number" and tick() - item.Clock < 2
                local shown = active or not state.hideUnused
                rows[i].title.Visible, rows[i].percent.Visible = shown, shown
                if shown then
                    local value = active and math.clamp(item.Value, 0, 1) or nil
                    rows[i].percent.Text = value and (tostring(math.round(value * 100)) .. "%") or "--"
                    rows[i].percent.TextColor3 = (value and state.showColor)
                        and Color3.fromHSV(value / 3, 0.7, 1) or Color3.fromRGB(231, 241, 250)
                    rows[i].title.Position = UDim2.fromOffset(9, 7 + count * 25)
                    rows[i].percent.Position = UDim2.fromOffset(155, 7 + count * 25)
                    count += 1
                end
            end
            empty.Visible = count == 0
            empty.Text = chances and "Waiting for hit-chance samples" or "Hit-chance telemetry unavailable"
            frame.Size = UDim2.fromOffset(212, math.max(31, 12 + count * 25))
        end
        life.accuracyRefresh = render
    end
end

-- Inventory Overlay: native options and 9-column grid with local inventory or
-- replicated other-player inventory when BedWars makes it available.
do
    local overlay, frame = addOverlay("Inventory Overlay", "inventory", 333, 130)
    if overlay then
        local state = {showHotbar = true, background = true, opacity = 0.35}
        createToggle(overlay, "Render Background", true, function(v) state.background = v end)
        createToggle(overlay, "Show Hotbar", true, function(v) state.showHotbar = v end)
        createSlider(overlay, "Transparency", 0, 95, 35, function(v) state.opacity = v / 100 end)
        local function names()
            local list = {"Self"}
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= lp then list[#list + 1] = player.Name end
            end
            table.sort(list, function(a, b)
                if a == "Self" then return true end
                if b == "Self" then return false end
                return a:lower() < b:lower()
            end)
            return list
        end
        local selected = overlay:CreateDropdown({Name = "Inventory", List = names(), Default = "Self"})
        local cells = {}
        for index = 1, 36 do
            local col = (index - 1) % 9
            local row = math.floor((index - 1) / 9)
            local tile = make("Frame", {
                BackgroundColor3 = Color3.fromRGB(38, 52, 66), BackgroundTransparency = 0.45,
                BorderSizePixel = 0, Position = UDim2.fromOffset(6 + col * 36, 6 + row * 36),
                Size = UDim2.fromOffset(32, 32)
            }, frame)
            corner(tile, 4)
            local image = make("ImageLabel", {BackgroundTransparency = 1,
                Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(24, 24),
                ScaleType = Enum.ScaleType.Fit, Visible = false}, tile)
            local abbreviation = label(tile, "", 3, 2, 27, 21, 8, Enum.TextXAlignment.Center)
            abbreviation.TextWrapped = true
            local amount = label(tile, "", 2, 21, 27, 10, 9, Enum.TextXAlignment.Right)
            cells[index] = {tile = tile, image = image, title = abbreviation, amount = amount}
        end
        local footer = label(frame, "", 8, 154, 317, 17, 10)
        local cachedStore, cachedInventory, cachedMeta, lastLookup = nil, nil, nil, 0
        local function getSources()
            if os.clock() - lastLookup < 4 then return end
            lastLookup = os.clock()
            pcall(function()
                local scripts = lp:FindFirstChild("PlayerScripts")
                local ts = scripts and scripts:FindFirstChild("TS")
                local storeModule = ts and ts:FindFirstChild("ui") and ts.ui:FindFirstChild("store")
                if storeModule then cachedStore = require(storeModule).ClientStore end
            end)
            pcall(function()
                local ts = ReplicatedStorage:FindFirstChild("TS")
                local inventoryModule = ts and ts:FindFirstChild("inventory") and ts.inventory:FindFirstChild("inventory-util")
                if inventoryModule then cachedInventory = require(inventoryModule).InventoryUtil end
            end)
            pcall(function()
                local ts = ReplicatedStorage:FindFirstChild("TS")
                local item = ts and ts:FindFirstChild("item") and ts.item:FindFirstChild("item-meta")
                if item then cachedMeta = require(item).getItemMeta end
            end)
        end
        local function decode(entry)
            if type(entry) == "table" then
                entry = entry.item or entry
                return entry.itemType or entry.Name, entry.amount or entry.Amount or 1
            end
            if typeof(entry) == "Instance" then return entry.Name, entry:GetAttribute("Amount") or 1 end
            if type(entry) == "string" then return entry, 1 end
            return nil, nil
        end
        local function render()
            if not overlay.Button.Enabled then return end
            local allPlayers = names()
            if table.concat(allPlayers, "|") ~= life.playerSignature then
                life.playerSignature = table.concat(allPlayers, "|")
                pcall(function() selected:Change(allPlayers) end)
            end
            getSources()
            local target = selected.Value == "Self" and lp or Players:FindFirstChild(selected.Value)
            local observed
            if target == lp and cachedStore then
                pcall(function()
                    local stateObj = cachedStore:getState()
                    observed = stateObj.Inventory and stateObj.Inventory.observedInventory
                end)
            end
            local inv
            if observed then
                inv = observed.inventory
            elseif target and cachedInventory and type(cachedInventory.getInventory) == "function" then
                pcall(function() inv = cachedInventory.getInventory(target) end)
            end
            local items = {}
            if type(inv) == "table" then
                for _, entry in pairs(inv.items or {}) do
                    local name, amount = decode(entry)
                    if name then items[#items + 1] = {name = name, amount = amount} end
                end
                if #items == 0 then
                    for _, entry in ipairs(inv.hotbar or {}) do
                        local name, amount = decode(entry)
                        if name then items[#items + 1] = {name = name, amount = amount} end
                    end
                end
            end
            local showRows = state.showHotbar and 4 or 3
            for index, cell in ipairs(cells) do
                local visible = index <= showRows * 9
                cell.tile.Visible = visible
                if visible then
                    local entry = items[index]
                    local name = entry and entry.name
                    cell.tile.BackgroundTransparency = state.background and 0.45 or 1
                    cell.title.Text = name and (name:gsub("_", " "):sub(1, 8)) or ""
                    cell.amount.Text = entry and entry.amount and entry.amount > 1 and tostring(entry.amount) or ""
                    cell.image.Visible = false
                    if name and cachedMeta then
                        local ok, meta = pcall(cachedMeta, name)
                        local image = ok and meta and meta.image
                        if type(image) == "number" then image = "rbxassetid://" .. image end
                        if type(image) == "string" and image ~= "" then
                            cell.image.Image = image
                            cell.image.Visible = true
                            cell.title.Text = ""
                        end
                    end
                end
            end
            footer.Position = UDim2.fromOffset(8, 10 + showRows * 36)
            footer.Text = target and (#items .. " items • " .. target.Name) or "Player unavailable"
            if not inv then footer.Text = "Inventory not currently replicated" end
            frame.BackgroundTransparency = state.background and state.opacity or 1
            frame.Size = UDim2.fromOffset(333, 33 + showRows * 36)
        end
        life.inventoryRefresh = render
    end
end

-- Visible Nexus branding; do not alter endpoint URLs, profile paths, or module keys.
-- Remove the optional config-port control without deleting profile storage APIs.
do
    local function renamed(value)
        local result = tostring(value or "")
        result = result:gsub("[Vv][Aa][Pp][Ee][Vv]4", "NexusV4")
        result = result:gsub("[Vv][Aa][Pp][Ee] [Vv]4", "NexusV4")
        result = result:gsub("[Cc][Aa][Tt][Vv][Aa][Pp][Ee]%.dev", "Nexus")
        result = result:gsub("[Cc][Aa][Tt][Vv][Aa][Pp][Ee]", "Nexus")
        result = result:gsub("[Tt]hank you for choosing Nexus[^\n]*", "Thanks for choosing Nexus")
        result = result:gsub("NexusV4  /  based on Nexus", "Thanks for choosing Nexus")
        return result
    end
    local function isPortControl(value)
        local test = tostring(value or ""):lower():gsub("%s+", " ")
        return test:find("port your own config", 1, true) ~= nil
            or test:find("port your config", 1, true) ~= nil
    end
    local function updateText(obj)
        if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
        local original = obj.Text
        -- Keep the new main-window title; hide stale copies produced by older versions.
        if obj.Name ~= "NexusV4Title"
            and tostring(original):lower():match("^%s*nexus%s*v4%s*$") then
            obj.Visible = false
            return
        end
        if isPortControl(original) then
            local button = obj
            for _ = 1, 5 do
                if button:IsA("TextButton") or button:IsA("ImageButton") then
                    button.Visible = false
                    break
                end
                button = button.Parent
                if not button or button == ui.Gui then break end
            end
            obj.Visible = false
            return
        end
        local result = renamed(original)
        if result ~= original then obj.Text = result end
    end
    local function updateAllText()
        if not (ui.Gui and ui.Gui.Parent) then return end
        for _, obj in ipairs(ui.Gui:GetDescendants()) do
            pcall(updateText, obj)
        end
    end
    updateAllText()
    connect(ui.Gui.DescendantAdded, function(obj)
        if life.alive then pcall(updateText, obj) end
    end)
    life.rebrandRefresh = updateAllText
    -- NEXUSV4 belongs on the main menu, not on its Settings / nested panels.
    -- Observe native pane visibility rather than trying to guess when gear clicks finish.
    pcall(function()
        local main = shared.Cat and shared.Cat.Window and shared.Cat.Window.Object
        if not (main and main.Parent) then return end
        -- Keep the former image logo out of the way.
        for _, obj in ipairs(main:GetChildren()) do
            if obj:IsA("ImageLabel") and obj.Position.X.Offset == 12 and obj.Size.X.Offset == 55 then
                obj.Visible = false
            end
        end
        local title = main:FindFirstChild("NexusV4Title")
        if not (title and title:IsA("TextLabel")) then
            title = track(make("TextLabel", {
                Name = "NexusV4Title", BackgroundTransparency = 1, BorderSizePixel = 0,
                Text = "NEXUSV4", Font = Enum.Font.GothamBold, TextSize = 15,
                TextColor3 = ui:Color(0), TextXAlignment = Enum.TextXAlignment.Left,
                Position = UDim2.fromOffset(12, 9), Size = UDim2.fromOffset(140, 22),
                ZIndex = 2
            }, main))
        else
            title.Text = "NEXUSV4"
        end
        local observed = {}
        local settingsButton = shared.Cat.Window and shared.Cat.Window.Settings
        -- Actual CatVape Pane objects are unnamed TextButtons containing a
        -- Frame called "Children". Their initial size is Scale(1,1), but the
        -- UIListLayout immediately resizes Y to an Offset (Y.Scale == 0).
        -- The former size-based check therefore missed the real Settings pane.
        local function isPane(child)
            if not child or child == settingsButton or not child:IsA("TextButton") then
                return false
            end
            local contents = child:FindFirstChild("Children")
            return contents ~= nil and contents:IsA("Frame")
        end
        local function refreshTitle()
            if not life.alive or not title.Parent then return end
            local panelOpen = false
            for _, child in ipairs(main:GetChildren()) do
                if isPane(child) and child.Visible then
                    panelOpen = true
                    break
                end
            end
            title.Visible = not panelOpen
            pcall(function() title.TextColor3 = ui:Color(0) end)
        end
        local function observePane(child)
            if observed[child] or not isPane(child) then return end
            observed[child] = true
            connect(child:GetPropertyChangedSignal("Visible"), refreshTitle)
            connect(child.AncestryChanged, refreshTitle)
        end
        for _, child in ipairs(main:GetChildren()) do observePane(child) end
        connect(main.ChildAdded, function(child)
            if not life.alive then return end
            observePane(child)
            refreshTitle()
        end)
        if settingsButton and settingsButton:IsA("GuiButton") then
            -- Hide on the same click, before any pane layout recalculation.
            connect(settingsButton.MouseButton1Click, function()
                if life.alive and title.Parent then title.Visible = false end
                task.defer(refreshTitle)
            end)
        end
        life.brandRefresh = refreshTitle
        refreshTitle()
    end)
end

-- Expose only AutoBlockUp in Utility. The native Scaffold implementation
-- stays loaded ONLY as an internal BedWars placement engine; its visible row,
-- favorites shortcut and binding are disabled. Removing the native Module
-- object would tear down the callbacks and placement code AutoBlockUp needs.
do
    local scaffold = ui.Modules and ui.Modules.Scaffold
    local utility = cat.Categories and cat.Categories.Utility
    if not (scaffold and utility and type(utility.CreateModule) == "function") then
        warnUser("AutoBlockUp unavailable: BedWars placement engine wasn't found")
    else
        -- Handle an in-place update without duplicate Utility entries.
        local previousModule = ui.Modules.AutoBlockUp
        if previousModule and type(previousModule.Remove) == "function" then
            pcall(previousModule.Toggle, previousModule, false)
            pcall(previousModule.Remove, previousModule)
        end

        local activeModule
        local serial = 0
        local forced = {
            ["Tower"] = true,
            ["Tower mode"] = "Block up",
            ["Expand"] = 1,
            ["Downwards"] = false,
            ["Diagonal"] = false,
            ["Require mouse down"] = false,
            ["Visual"] = false,
            ["Block Count"] = false
        }
        local function hideEngine()
            if scaffold.Object and scaffold.Object.Parent then
                scaffold.Object.Visible = false
            end
            if scaffold.Children and scaffold.Children.Parent then
                scaffold.Children.Visible = false
            end
            if scaffold.Favorited and type(scaffold.SetFavorite) == "function" then
                pcall(scaffold.SetFavorite, scaffold, false)
            end
            -- Otherwise a previously saved Scaffold hotkey can switch on the
            -- hidden backend independently of AutoBlockUp.
            if scaffold.Bind and type(scaffold.Bind.Keys) == "table"
                and #scaffold.Bind.Keys > 0 and type(scaffold.Bind.SetBind) == "function" then
                pcall(scaffold.Bind.SetBind, scaffold.Bind, {})
            end
        end
        local function halt()
            if scaffold.Enabled then
                pcall(scaffold.Toggle, scaffold, false)
            end
        end
        local function put(name, target)
            local setting = scaffold.Options and scaffold.Options[name]
            if type(setting) ~= "table" then return false end
            if setting.Enabled ~= nil then
                if setting.Enabled ~= target then
                    local ok = pcall(setting.Toggle, setting, target)
                    if not ok then return false end
                end
            elseif setting.Value ~= target then
                if type(setting.SetValue) ~= "function" then return false end
                local ok = pcall(setting.SetValue, setting, target)
                if not ok then return false end
            end
            return true
        end
        local function configure()
            for name, target in pairs(forced) do
                if not put(name, target) then return false, name end
            end
            return true
        end

        -- Clear any old profile state before offering the replacement toggle.
        halt()
        hideEngine()
        -- Saved Scaffold settings and its own keybind must not leak back as a
        -- second, invisible control. We intentionally do NOT restore the old
        -- Scaffold state on AutoBlockUp disable.
        activeModule = utility:CreateModule({
            Name = "AutoBlockUp",
            Tooltip = "Hold Space to build upward. Disabling stops block placement and restores normal jumping.",
            Function = function(enabled)
                serial += 1
                local ticket = serial
                if not enabled then
                    halt()
                    return
                end
                if not life.alive or not activeModule or not activeModule.Enabled then
                    halt()
                    return
                end
                local ready, missing = configure()
                if not ready then
                    warnUser("AutoBlockUp unavailable: missing setting " .. tostring(missing))
                    halt()
                    if activeModule.Enabled then activeModule:Toggle(false) end
                    return
                end
                if not life.alive or ticket ~= serial or not activeModule.Enabled then
                    halt()
                    return
                end
                if not scaffold.Enabled then
                    local ok = pcall(scaffold.Toggle, scaffold, true)
                    if not ok then
                        halt()
                        if activeModule.Enabled then activeModule:Toggle(false) end
                    end
                end
            end
        })

        -- Profile loading is queued by the original UI. It can run after
        -- installation, so re-hide/re-disable native Scaffold if it reappears.
        local refreshTicks = 0
        life.autoBlockRefresh = function()
            if not life.alive then return end
            hideEngine()
            if activeModule.Removed then
                halt()
                return
            end
            if not activeModule.Enabled then
                halt()
                return
            end
            refreshTicks += 1
            -- Enforce Block up if a profile load rewrites Scaffold's options.
            if refreshTicks % 3 == 0 then
                local valid = configure()
                if not valid then
                    activeModule:Toggle(false)
                    halt()
                    return
                end
            end
            if not scaffold.Enabled then
                pcall(scaffold.Toggle, scaffold, true)
            end
        end
        life.autoBlockCleanup = function()
            serial += 1
            if activeModule and not activeModule.Removed then
                if activeModule.Enabled then pcall(activeModule.Toggle, activeModule, false) end
                if type(activeModule.Remove) == "function" then
                    pcall(activeModule.Remove, activeModule)
                end
            end
            halt()
        end
    end
end

-- World -> Potato Graphics: native Nexus module and native changeable keybind.
-- Borrow only the supplied texture/material simplification code, not its UI or icon.
do
    if cat.Categories and cat.Categories.World and not ui.Modules["Potato Graphics"] then
        local Workspace = workspace
        local Players = game:GetService("Players")
        local function connect(signal, callback)
            return signal:Connect(callback)
        end
    local COLORS = {}

    local function add(color, names)
        for name in names:gmatch("%S+") do
            COLORS[name] = color
        end
    end

    add(Color3.fromRGB(0,0,0), "galactite galactite_brick")
    add(Color3.fromRGB(145,65,210), "void_grass")
    add(Color3.fromRGB(235, 145, 35), "amber_leaves")
    add(Color3.fromRGB(165,165,165), "clay")
    add(Color3.fromRGB(35,35,35), "clay_black")
    add(Color3.fromRGB(55,110,190), "clay_blue")
    add(Color3.fromRGB(85,55,40), "clay_dark_brown")
    add(Color3.fromRGB(45,95,55), "clay_dark_green")
    add(Color3.fromRGB(125,125,130), "clay_gray")
    add(Color3.fromRGB(180,135,95), "clay_light_brown")
    add(Color3.fromRGB(130,185,110), "clay_light_green")
    add(Color3.fromRGB(225,125,45), "clay_orange")
    add(Color3.fromRGB(235,145,175), "clay_pink")
    add(Color3.fromRGB(140,75,185), "clay_purple")
    add(Color3.fromRGB(190,55,55), "clay_red")
    add(Color3.fromRGB(195,165,120), "clay_tan")
    add(Color3.fromRGB(235,235,230), "clay_white")
    add(Color3.fromRGB(230,200,65), "clay_yellow")
    add(Color3.fromRGB(240,240,240), "wool_white wool wool_builder")
    add(Color3.fromRGB(30,30,30), "wool_black")
    add(Color3.fromRGB(190,45,45), "wool_red")
    add(Color3.fromRGB(55,105,190), "wool_blue")
    add(Color3.fromRGB(55,145,65), "wool_green")
    add(Color3.fromRGB(235,205,55), "wool_yellow")
    add(Color3.fromRGB(235,130,45), "wool_orange")
    add(Color3.fromRGB(235,145,175), "wool_pink")
    add(Color3.fromRGB(135,70,185), "wool_purple")
    add(Color3.fromRGB(65,195,205), "wool_cyan")
    add(Color3.fromRGB(115,75,45), "wool_brown")
    add(Color3.fromRGB(125,82,48), "wood oak_log")
    add(Color3.fromRGB(175,130,80), "wood_plank_oak wood_plank_oak_builder")
    add(Color3.fromRGB(220,195,145), "wood_plank_birch birch_log")
    add(Color3.fromRGB(185,105,55), "wood_plank_maple")
    add(Color3.fromRGB(105,75,50), "wood_plank_spruce spruce_log")
    add(Color3.fromRGB(145,100,65), "hickory_log")
    add(Color3.fromRGB(85,85,90), "stone_brick stone_brick_builder stone_tiles steel_block andesite andesite_polished diorite diorite_polished granite granite_polished")
    add(Color3.fromRGB(130,130,135), "stone cobblestone stone_slab stone_pillar kobblak")
    add(Color3.fromRGB(105,105,110), "slate_brick slate_tiles marble marble_pillar polished_andesite polished_diorite polished_granite")
    add(Color3.fromRGB(20,20,25), "obsidian")
    add(Color3.fromRGB(65,145,65), "grass")
    add(Color3.fromRGB(35,95,45), "moss_block")
    add(Color3.fromRGB(115,80,55), "dirt void_dirt")
    add(Color3.fromRGB(210,190,135), "sand sandstone sandstone_smooth sandstone_polished smooth_sandstone")
    add(Color3.fromRGB(190,135,95), "red_sand")
    add(Color3.fromRGB(175,95,60), "red_sandstone red_sandstone_smooth red_sandstone_polished smooth_red_sandstone")
    add(Color3.fromRGB(130,190,220), "glass blue_tile")
    add(Color3.fromRGB(80,140,90), "concrete_green")
    add(Color3.fromRGB(165,85,65), "brick")
    add(Color3.fromRGB(190,195,200), "iron_block")
    add(Color3.fromRGB(80,220,220), "diamond_block diamond_capture_block")
    add(Color3.fromRGB(50,190,105), "emerald_block")
    add(Color3.fromRGB(230,190,65), "gold_block")
    add(Color3.fromRGB(85,55,35), "barrel")
    add(Color3.fromRGB(220,185,65), "haybale")
    add(Color3.fromRGB(235,195,65), "lantern_block glowstone")
    add(Color3.fromRGB(80,190,210), "aquamarine_lantern")
    add(Color3.fromRGB(115,80,45), "bookshelf")
    add(Color3.fromRGB(160,110,65), "copper_block")
    add(Color3.fromRGB(45,45,50), "bedrock")
    add(Color3.fromRGB(180,220,240), "ice")
    add(Color3.fromRGB(235,240,245), "snow")
    add(Color3.fromRGB(220,135,55), "pumpkin_block")
    add(Color3.fromRGB(130,85,55), "nest")
    add(Color3.fromRGB(125,125,125), "gum_block pot gravel")
    add(Color3.fromRGB(240,235,210), "limestone limestone_block")
    add(Color3.fromRGB(155,215,245), "ice_bricks")
    add(Color3.fromRGB(20,20,25), "tuff_bricks")
    add(Color3.fromRGB(235,235,235), "guilded_iron guilded_iron_block")
    add(Color3.fromRGB(65,145,65), "small_bush large_bush")
    add(Color3.fromRGB(115,80,45), "wilted_foliage")
    add(Color3.fromRGB(125,185,195), "spirit_grass")
    add(Color3.fromRGB(100,175,185), "spirit_foliage")
    add(Color3.fromRGB(225,145,175), "cherry_foliage")
    add(Color3.fromRGB(145,65,210), "flower_purple purple_flower")
    add(Color3.fromRGB(235,130,45), "flower_orange orange_flower")
    add(Color3.fromRGB(65,145,210), "flower_blue blue_flower")
    add(Color3.fromRGB(225,145,175), "flower_pink pink_flower")
    add(Color3.fromRGB(190,175,145), "ceramic")
    add(Color3.fromRGB(190,65,30), "magma_block")
    add(Color3.fromRGB(100,190,90), "slime_block")
    add(Color3.fromRGB(100,165,65), "melon")
    add(Color3.fromRGB(230,125,35), "carrot")
    add(Color3.fromRGB(220,105,125), "coral_block coral")
    add(Color3.fromRGB(90,90,100), "smoke_block")
    add(Color3.fromRGB(175,130,80), "oak_wood_plank oak_plank oak_plank_wall")
    add(Color3.fromRGB(190,45,45), "flag pirate_flag")
    add(Color3.fromRGB(110,80,65), "volatile_stone")
    add(Color3.fromRGB(80,140,90), "radioactive_plant")

    local BLOCKS = {}

    local function normalizeName(name)
        name = tostring(name):lower()
        name = name:gsub("[%s%-]+", "_")
        name = name:gsub("_+", "_")
        return name
    end

    for name, color in pairs(COLORS) do
        BLOCKS[normalizeName(name)] = color
    end

    local Originals = {}
    local Enabled = false

    local function saveOriginal(instance)
        if Originals[instance] then return end

        local data = {}

        if instance:IsA("BasePart") then
            data.Color = instance.Color
            data.Material = instance.Material
            data.MaterialVariant = instance.MaterialVariant
        elseif instance:IsA("Decal") or instance:IsA("Texture") then
            data.Transparency = instance.Transparency
        elseif instance:IsA("SpecialMesh") then
            data.TextureId = instance.TextureId
        elseif instance:IsA("SurfaceAppearance") then
            data.ColorMap = instance.ColorMap
            data.MetalnessMap = instance.MetalnessMap
            data.NormalMap = instance.NormalMap
            data.RoughnessMap = instance.RoughnessMap

        end

        Originals[instance] = data
    end

    local function isLuckyBlock(instance)
        local current = instance

        while current and current ~= Workspace do
            local name = normalizeName(current.Name)

            if name:find("lucky_block", 1, true)
                or name:find("luckyblock", 1, true)
                or name:find("lucky_crate", 1, true)
                or name:find("lucky_pot", 1, true) then
                return true
            end

            current = current.Parent
        end

        return false
    end

    local function isOre(instance)
        local current = instance

        while current and current ~= Workspace do
            local name = normalizeName(current.Name)

            if name == "ore"
                or name:match("%f[%w]ore%f[%W]")
                or name:match("^ore_")
                or name:match("_ore$") then
                return true
            end

            current = current.Parent
        end

        return false
    end

    local function isPlayerCharacter(part)
        local model = part:FindFirstAncestorOfClass("Model")

        return model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
    end

    -- Do not modify enchanting stations, equipped items or first-person hand models.
    -- These assets rely on their original material, mesh and texture maps.
    local function isProtectedVisual(instance)
        local current = instance
        local camera = Workspace.CurrentCamera
        while current do
            local name = normalizeName(current.Name)
            if name == "enchant_table" or name == "enchantment_table" then
                return true
            end
            if current:IsA("Tool") or current:IsA("Accessory") then
                return true
            end
            if current == camera or current:IsA("Backpack") then
                return true
            end
            if current:IsA("Model") then
                if Players:GetPlayerFromCharacter(current) then
                    return true
                end
                if name == "viewmodel" or name == "view_model"
                    or name == "firstperson" or name == "first_person"
                    or name == "handmodel" or name == "held_item"
                    or name == "helditem" then
                    return true
                end
            end
            current = current.Parent
        end
        return false
    end

    local function getBlockColor(part)
        local current = part

        while current and current ~= Workspace do
            local color = BLOCKS[normalizeName(current.Name)]

            if color then
                return color
            end

            current = current.Parent
        end

        return nil
    end

    -- Only identified placed blocks are changed.
    local function isBlockVisual(instance)
        if isLuckyBlock(instance) or isOre(instance) or isProtectedVisual(instance) then
            return false
        end
        local current = instance
        while current and current ~= Workspace do
            if current:IsA("BasePart") then
                if isPlayerCharacter(current) then return false end
                return getBlockColor(current) ~= nil
            end
            current = current.Parent
        end
        return false
    end

    local function removeTexture(instance)
        if not isBlockVisual(instance) then return end
        if not (instance:IsA("Decal") or instance:IsA("Texture")
            or instance:IsA("SpecialMesh") or instance:IsA("SurfaceAppearance")) then return end

        saveOriginal(instance)
        pcall(function()
            if instance:IsA("Decal") or instance:IsA("Texture") then
                instance.Transparency = 1
            elseif instance:IsA("SpecialMesh") then
                instance.TextureId = ""
            elseif instance:IsA("SurfaceAppearance") then
                instance.ColorMap = ""
                instance.MetalnessMap = ""
                instance.NormalMap = ""
                instance.RoughnessMap = ""
            end
        end)
    end

    local function applyPart(part)
        if not Enabled or not part:IsA("BasePart") then return end
        if isLuckyBlock(part) or isOre(part) or isProtectedVisual(part) then return end
        if isPlayerCharacter(part) then return end

        local color = getBlockColor(part)
        if not color then return end

        saveOriginal(part)
        part.Color = color
        part.Material = Enum.Material.SmoothPlastic
        part.MaterialVariant = ""

        for _, child in ipairs(part:GetDescendants()) do
            removeTexture(child)
        end
    end

    local function restoreOriginals()
        Enabled = false

        for instance, data in pairs(Originals) do
            if instance and instance.Parent then
                pcall(function()
                    if instance:IsA("BasePart") then
                        instance.Color = data.Color
                        instance.Material = data.Material
                        instance.MaterialVariant = data.MaterialVariant
                    elseif instance:IsA("Decal") or instance:IsA("Texture") then
                        instance.Transparency = data.Transparency
                    elseif instance:IsA("SpecialMesh") then
                        instance.TextureId = data.TextureId
                    elseif instance:IsA("SurfaceAppearance") then
                        instance.ColorMap = data.ColorMap
                        instance.MetalnessMap = data.MetalnessMap
                        instance.NormalMap = data.NormalMap
                        instance.RoughnessMap = data.RoughnessMap
                    end
                end)
            end
        end

        table.clear(Originals)

    end

    local potatoGeneration = 0
    local potatoConnection
    local function scanWorld()
        local myGeneration = potatoGeneration
        task.spawn(function()
            for index, instance in ipairs(Workspace:GetDescendants()) do
                if not Enabled or not life.alive or myGeneration ~= potatoGeneration then break end
                if instance:IsA("BasePart") then applyPart(instance) end
                if index % 140 == 0 then task.wait() end
            end
        end)
    end
        local function stopPotato()
            potatoGeneration += 1
            Enabled = false
            if potatoConnection then
                potatoConnection:Disconnect()
                potatoConnection = nil
            end
            restoreOriginals()
        end
        local function startPotato()
            if Enabled or not life.alive then return end
            Enabled = true
            potatoGeneration += 1
            potatoConnection = connect(Workspace.DescendantAdded, function(instance)
                if not Enabled then return end
                local epoch = potatoGeneration
                task.defer(function()
                    if not Enabled or epoch ~= potatoGeneration or not life.alive or not instance.Parent then return end
                    if instance:IsA("BasePart") then
                        applyPart(instance)
                    else
                        removeTexture(instance)
                    end
                end)
            end)
            scanWorld()
        end
        local module
        module = cat.Categories.World:CreateModule({
            Name = "Potato Graphics",
            Keybind = "F6",
            Tooltip = "Simplifies placed block textures and materials for performance. F6 toggles by default; change the bind from Nexus settings.",
            Function = function(on)
                if not life.alive or not module or module.Enabled ~= on then return end
                if on then startPotato() else stopPotato() end
            end
        })
        life.potatoCleanup = function()
            stopPotato()
            if module and not module.Removed then pcall(module.Remove, module) end
        end
    end
end

-- FOV has two distinct meanings: the Roblox camera is hard-limited to 120 degrees,
-- while the native AimAssist's angular target cone genuinely supports up to 360 degrees.
do
    local fovModule = cat.Legit and cat.Legit.Modules and cat.Legit.Modules.FOV
    local aim = ui.Modules.AimAssist
    local nativeCamera = workspace.CurrentCamera
    local cameraConnection
    local savedCamera
    if not fovModule and cat.Legit then
        local cameraSlider
        fovModule = cat.Legit:CreateModule({
            Name = "FOV", Category = "Game", Icon = "legit_fov",
            Tooltip = "Camera field of view is capped by Roblox at 120 degrees. Target angle can reach 360.",
            Function = function(on)
                if on then
                    savedCamera = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
                    cameraConnection = connect(RunService.RenderStepped, function()
                        local current = workspace.CurrentCamera
                        if current and cameraSlider then
                            current.FieldOfView = math.clamp(cameraSlider.Value, 30, 120)
                        end
                    end)
                else
                    if cameraConnection then cameraConnection:Disconnect(); cameraConnection = nil end
                    local current = workspace.CurrentCamera
                    if current and savedCamera then current.FieldOfView = savedCamera end
                    savedCamera = nil
                end
            end
        })
        cameraSlider = fovModule:CreateSlider({Name = "Camera FOV", Min = 30, Max = 120, Default = 90,
            Suffix = "degrees", Tooltip = "Roblox renders at most 120 vertical degrees"})
        life.fovCleanup = function()
            if cameraConnection then cameraConnection:Disconnect(); cameraConnection = nil end
            if savedCamera and workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = savedCamera end
        end
    end
    if fovModule and aim and aim.Options and aim.Options["Max angle"]
        and not (fovModule.Options and fovModule.Options["Target FOV"]) then
        local nativeAngle = aim.Options["Max angle"]
        fovModule:CreateSlider({
            Name = "Target FOV", Min = 1, Max = 360,
            Default = math.clamp(tonumber(nativeAngle.Value) or 70, 1, 360),
            Suffix = "degrees",
            Tooltip = "Controls AimAssist's actual 360-degree target-selection cone; does not expand the camera beyond 120 degrees.",
            Function = function(angle)
                if nativeAngle and type(nativeAngle.SetValue) == "function" then
                    nativeAngle:SetValue(math.clamp(tonumber(angle) or 70, 1, 360))
                end
            end
        })
    end
end

-- Nexus native Hitreg 36 preference (OFFICIAL MODULE FIRST).
-- Never replace HitFix, HitregAdjuster or their internal hit-rate algorithms.
-- Set only an exposed native numeric slider whose declared range includes 36.
-- If the latest developer module has no such option, report that fact instead
-- of changing an unrelated number or falsely changing the HitFix tooltip.
do
    local function setNativeHitreg36()
        local modules = ui and ui.Modules
        if type(modules) ~= "table" then return false end
        for _, moduleName in ipairs({"HitFix", "HitregAdjuster"}) do
            local module = modules[moduleName]
            local options = module and module.Options
            if type(options) == "table" then
                for _, optionName in ipairs({"Hitreg", "Hits / 10s", "Hits per 10s", "Hits per 10 seconds", "Hit count", "Hits"}) do
                    local option = options[optionName]
                    if type(option) == "table"
                        and type(option.SetValue) == "function"
                        and type(option.Min) == "number"
                        and type(option.Max) == "number"
                        and option.Min <= 36 and option.Max >= 36 then
                        local ok, reason = pcall(function()
                            option:SetValue(36, true)
                        end)
                        if ok and tonumber(option.Value) == 36 then
                            print("[Nexus] Official " .. moduleName .. "/" .. optionName .. " configured for 36 hits per 10s (client-side target; not a guarantee)")
                            return true
                        elseif not ok then
                            warn("[Nexus] Official " .. moduleName .. " rate setting rejected 36: " .. tostring(reason))
                        end
                    end
                end
            end
        end
        return false
    end
    task.spawn(function()
        -- Allow the developer's async configuration restore to complete.
        task.wait(2.5)
        local started = os.clock()
        local configured = false
        repeat
            if not life.alive or not ui or ui.Dead then return end
            configured = setNativeHitreg36()
            if not configured then task.wait(0.75) end
        until configured or os.clock() - started > 10
        if not configured then
            warn("[Nexus] Native 36-hit setting not exposed by this official CatVape build; HitFix and HitregAdjuster were preserved unchanged")
        end
    end)
end

-- One cancellable low-rate worker updates only enabled overlays.
task.spawn(function()
    local iteration = 0
    while life.alive and ui.Gui and ui.Gui.Parent and not ui.Dead do
        iteration += 1
        if life.autoBlockRefresh then pcall(life.autoBlockRefresh) end
        if iteration % 14 == 0 and life.rebrandRefresh then
            pcall(life.rebrandRefresh)
            if life.brandRefresh then pcall(life.brandRefresh) end
        end
        for _, action in ipairs({life.keybindRefresh, life.accuracyRefresh}) do
            if type(action) == "function" then
                local ok, err = pcall(action)
                if not ok and iteration % 50 == 1 then warn("[CV overlays] " .. tostring(err)) end
            end
        end
        if iteration % 2 == 0 then
            for _, action in ipairs({life.bedRefresh, life.inventoryRefresh}) do
                if type(action) == "function" then
                    local ok, err = pcall(action)
                    if not ok and iteration % 50 == 2 then warn("[CV overlays] " .. tostring(err)) end
                end
            end
        end
        task.wait(0.3)
    end
end)

print("[NexusV4] Keybinds, Bed Defense, Hit Accuracy, Inventory Overlay, AutoBlockUp, FOV and Potato Graphics installed; Scaffold UI hidden")
