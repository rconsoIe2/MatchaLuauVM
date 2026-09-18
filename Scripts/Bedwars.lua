if not _G.loadedFromMain then
    local mainSource = ""
    pcall(function()
        if _G.developer then
            mainSource = readfile("rise/main.lua")
        else
            mainSource = game:HttpGet("https://raw.githubusercontent.com/rconsoIe2/MatchaLuauVM/refs/heads/main/main.lua")
        end
    end)

    if type(mainSource) == "string" and #mainSource > 0 then
        _G.loadedFromMain = true
        loadstring(mainSource)()
    else
        print("Bedwars.lua: main.lua not available")
    end
    return
end

local LibSource
if _G.developer then
    LibSource = readfile("rise/libraries/RiseUI.lua")
else
    LibSource = game:HttpGet("https://raw.githubusercontent.com/rconsoIe2/MatchaLuauVM/refs/heads/main/Libraries/RiseUI.lua")
end
local Lib = loadstring(LibSource)() or RiseUI
local HttpService = game:GetService("HttpService")

local settings = {
    Player = false,
    Bed = false,
    Entity = false,
    ShowKit = false,
    ShowEquipped = false,
    Metal = false,
    Bee = false,
    Eldertree = false,
    Star = false,
    iron = false,
    diamond = false,
    emerald = false,
    Visible = false,
    Amount = false,
    Distance = 500,
    Killaura = false,
    TargetEntities = true,
    TeamCheck = true,
    SwingRange = 28,
    AngleValue = 360,
    RequireMouseDown = false,
    NoSwing = false,
    FaceTarget = false,
    LimitToItems = false,
    SwingOnly = false,
    WallCheck = false,
    AutoKit = false,
    AutoKitRange = 18,
    AutoVoidDrop = false,
    OwlCheck = true,
    Fishing = false
}

local configPath = "rise/configs/" .. tostring(game.PlaceId) .. ".json"

local function saveConfig()
    pcall(function()
        writefile(configPath, HttpService:JSONEncode(settings))
    end)
end

local function loadConfig()
    pcall(function()
        if isfile(configPath) then
            local content = readfile(configPath)
            if content and #content > 0 then
                local parsed = HttpService:JSONDecode(content)
                if type(parsed) == "table" then
                    for key, val in pairs(parsed) do
                        if settings[key] ~= nil then
                            settings[key] = val
                        end
                    end
                end
            end
        end
    end)
end

loadConfig()

local win = Lib:CreateWindow({ 
    title = "Rise", 
    size = Vector2.new(560, 400) 
})

local blatantTab = win:Tab("Blatant")
local blatantSec = blatantTab:Section("Combat", "Left")
local killAuraCategory = blatantSec:Category("Kill Aura")

local tab = win:Tab("Utility")
local sec = tab:Section("ESP", "Left")
local gameEsp = sec:Category("Game ESP")
local kitEsp = sec:Category("Kit ESP")
local itemEsp = sec:Category("Items ESP")
local espOptions = sec:Category("Options")

local autoKitSec = tab:Section("Automation", "Right")
local autoKitCategory = autoKitSec:Category("Auto Kit")
local autoVoidDropCategory = autoKitSec:Category("Auto Void Drop")
local autoFishingCategory = autoKitSec:Category("Auto Fisher")

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local NetManaged = ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
local SwordHitEvent = NetManaged:WaitForChild("SwordHit")
local CollectEvent = NetManaged:WaitForChild("CollectCollectableEntity")
local PickUpBeeEvent = NetManaged:WaitForChild("PickUpBee")
local DropItemRemote = NetManaged:WaitForChild("DropItem")
local Inventories = ReplicatedStorage:WaitForChild("Inventories")

local trackedObjects = {}
local Attacking = false
local armC0 = nil
local AnimTween = nil
local AnimDelay = tick()

local swordList = {
    "wood_sword", "stone_sword", "iron_sword", "diamond_sword", "og_diamond_sword", "ice_sword", "emerald_sword", "og_emerald_sword", "void_sword", "glitch_wood_sword", "glitch_void_sword", 
    "wood_dao", "stone_dao", "iron_dao", "diamond_dao", "emerald_dao", 
    "wood_dagger", "stone_dagger", "iron_dagger", "diamond_dagger", "mythic_dagger", 
    "wood_scythe", "stone_scythe", "iron_scythe", "diamond_scythe", "mythic_scythe", "scythe", "reaper_scythe", "sky_scythe", 
    "wood_gauntlets", "stone_gauntlets", "iron_gauntlets", "diamond_gauntlets", "mythic_gauntlets_plain", "mythic_gauntlets", 
    "rageblade", "double_edge_sword", "spirit_dagger", "spirit_dagger_left", "pirate_sword_fp", "cutlass_ghost", "big_wood_sword", "heavenly_sword", "infernal_saber", "bear_claws", "baguette", "knockback_fish", 
    "taser", "glitch_taser", "hot_potato", "frying_pan", "juggernaut_rage_blade", "battle_axe", "mass_hammer", "twirlblade", "noctium_blade", "noctium_blade_2", "noctium_blade_3", "noctium_blade_4", 
    "laser_sword", "frosty_hammer", "sparkler", "toy_hammer", "rainbow_axe", "wizard_stick", "hero_magical_girl_rapier", "villain_magical_girl_rapier", "hero_scissor_sword", "villain_scissor_sword", 
    "wood_gun_blade", "stone_gun_blade", "iron_gun_blade", "diamond_gun_blade", "emerald_gun_blade", "pillow", "iron_pickaxe_sword", "diamond_pickaxe_sword", "knight_shield", "tinkers_wrench", "whisper_feather", 
    "super_guitar", "guards_spear"
}

local function getEquippedWeaponDirect()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    for _, swordName in ipairs(swordList) do
        local found = char:FindFirstChild(swordName)
        if found and found:IsA("Tool") then
            return found
        end
    end
    return nil
end

local function getPlayerKit(char)
    local plr = Players:FindFirstChild(char.Name)
    if plr then
        local kit = plr:GetAttribute("PlayingAsKits") or plr:GetAttribute("PlayingAsKit")
        if kit then return tostring(kit) end
    end
    return "None"
end

local function getEquippedItem(char)
    for _, child in ipairs(char:GetChildren()) do
        if child:GetAttribute("InvItem") == true then
            return child.Name
        end
    end
    return "None"
end

local function getInventoryItem(itemName)
    local inventoryFolder = Inventories:FindFirstChild(LocalPlayer.Name)
    if inventoryFolder then
        for _, tool in ipairs(inventoryFolder:GetChildren()) do
            if tool and tool:IsA("Tool") then
                local toolName = string.lower(tool.Name)
                if toolName == string.lower(itemName) or toolName:find(string.lower(itemName)) then
                    local amount = tool:GetAttribute("Amount") or 1
                    return {tool = tool, amount = amount}
                end
            end
        end
    end
    return nil
end

local espConfigs = {
    Player = {
        validator = function(obj)
            if obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") and obj:FindFirstChild("Humanoid") then
                if obj == LocalPlayer.Character or obj.Name == LocalPlayer.Name then return false end
                local plr = Players:FindFirstChild(obj.Name)
                return plr ~= nil and plr ~= LocalPlayer
            end
            return false
        end,
        getTarget = function(obj) return obj:FindFirstChild("HumanoidRootPart") end,
        text = function(obj) return obj.Name end,
        color = Color3.fromRGB(255, 255, 255)
    },
    Entity = {
        validator = function(obj)
            if obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") and obj:FindFirstChild("Humanoid") then
                if obj == LocalPlayer.Character or obj.Name == LocalPlayer.Name then return false end
                return Players:FindFirstChild(obj.Name) == nil
            end
            return false
        end,
        getTarget = function(obj) return obj:FindFirstChild("HumanoidRootPart") end,
        text = function(obj) return obj.Name end,
        color = Color3.fromRGB(255, 100, 100)
    },
    Bed = {
        validator = function(obj)
            return (obj:IsA("MeshPart") and string.lower(obj.Name) == "bed") or (obj:IsA("Model") and obj.Name == "bed")
        end,
        getTarget = function(obj)
            if obj:IsA("Model") then
                return obj:FindFirstChildWhichIsA("BasePart") or obj.PrimaryPart
            end
            return obj
        end,
        text = "Bed",
        color = Color3.fromRGB(255, 0, 120)
    },
    Metal = {
        validator = function(obj) 
            return obj:IsA("Model") and obj:FindFirstChild("hidden-metal-prompt") and obj:FindFirstChild("Part") 
        end,
        getTarget = function(obj) return obj.Part end,
        text = "Metal",
        color = Color3.fromRGB(0, 255, 255)
    },
    Bee = {
        validator = function(obj) return obj.Name == "Bee" and obj:FindFirstChild("Root") end,
        getTarget = function(obj) return obj.Root end,
        text = "Bee",
        color = Color3.fromRGB(255, 255, 0)
    },
    Eldertree = {
        validator = function(obj) return obj.Name == "TreeOrb" and obj:FindFirstChild("Spirit") end,
        getTarget = function(obj) return obj.Spirit end,
        text = "Eldertree",
        color = Color3.fromRGB(0, 255, 0)
    },
    Star = {
        validator = function(obj) 
            return (obj.Name == "CritStar" or obj.Name == "VitalityStar") and obj:FindFirstChild("RootPart") 
        end,
        getTarget = function(obj) return obj.RootPart end,
        text = function(obj) return obj.Name == "CritStar" and "Crit Star" or "Vitality Star" end,
        color = function(obj) 
            return obj.Name == "CritStar" and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(144, 238, 144) 
        end
    },
    iron = {
        validator = function(obj) return obj:IsA("BasePart") and obj.Name == "iron" and obj.Parent and obj.Parent.Name == "ItemDrops" end,
        getTarget = function(obj) return obj end,
        text = "Iron",
        color = Color3.fromRGB(200, 200, 200)
    },
    diamond = {
        validator = function(obj) return obj:IsA("BasePart") and obj.Name == "diamond" and obj.Parent and obj.Parent.Name == "ItemDrops" end,
        getTarget = function(obj) return obj end,
        text = "Diamond",
        color = Color3.fromRGB(0, 191, 255)
    },
    emerald = {
        validator = function(obj) return obj:IsA("BasePart") and obj.Name == "emerald" and obj.Parent and obj.Parent.Name == "ItemDrops" end,
        getTarget = function(obj) return obj end,
        text = "Emerald",
        color = Color3.fromRGB(0, 230, 115)
    }
}

local function getUniqueIdentifier(model)
    return model.Address or tostring(model)
end

local cachedImages = {}
local function loadImage(fileName)
    local cached = cachedImages[fileName]
    if cached and #cached > 0 then
        return cached
    end

    if type(_G) == "table" then
        local persisted = type(_G.rise_images) == "table" and _G.rise_images[fileName] or nil
        if type(persisted) == "string" and #persisted > 0 then
            cachedImages[fileName] = persisted
            return persisted
        end
    end

    local filePath = "rise/assets/" .. fileName
    local img = ""
    if isfile(filePath) then
        pcall(function()
            img = readfile(filePath)
        end)
    end

    if type(img) == "string" and #img > 0 then
        cachedImages[fileName] = img
        pcall(function()
            local images = _G.rise_images
            if type(images) ~= "table" then images = {} end
            images[fileName] = img
            _G.rise_images = images
        end)
    end

    return cachedImages[fileName]
end

local function downloadRepoDir(repoPath, localPath, allowedExts)
    local ok, body = pcall(function()
        return game:HttpGet("https://api.github.com/repos/rconsoIe2/MatchaLuauVM/contents/" .. repoPath)
    end)
    if not ok or type(body) ~= "string" or #body == 0 then return end

    local decoded
    local ok2 = pcall(function()
        decoded = HttpService:JSONDecode(body)
    end)
    if not ok2 or type(decoded) ~= "table" then return end

    for _, entry in ipairs(decoded) do
        local name = entry and entry.name
        if type(name) == "string" and entry.download_url then
            local ext = name:match("%.([%w]+)$")
            if ext and allowedExts[ext:lower()] then
                local filePath = localPath .. name
                if not isfile(filePath) then
                    local data = game:HttpGet(entry.download_url)
                    if type(data) == "string" and #data > 0 then
                        writefile(filePath, data)
                    end
                end
            end
        end
    end
end

local function ensureRiseFiles()
    pcall(function()
        if not isfolder("rise") then makefolder("rise") end
        if not isfolder("rise/assets") then makefolder("rise/assets") end
        if not isfolder("rise/libraries") then makefolder("rise/libraries") end
        if not isfolder("rise/scripts") then makefolder("rise/scripts") end

        downloadRepoDir("Assets", "rise/assets/", { dat = true })
        downloadRepoDir("Libraries", "rise/libraries/", { lua = true, luau = true })
        downloadRepoDir("Scripts", "rise/scripts/", { lua = true, luau = true })
    end)
end

if not _G.developer then
    ensureRiseFiles()
end

local function getImageFile(espType, obj)
    if espType == "Metal" then
        return "iron.dat"
    elseif espType == "Bee" then
        return "bee.dat"
    elseif espType == "Star" then
        return obj.Name == "CritStar" and "crit_star.dat" or "vitality_star.dat"
    elseif espType == "iron" then
        return "iron.dat"
    elseif espType == "diamond" then
        return "diamond.dat"
    elseif espType == "emerald" then
        return "emerald.dat"
    end
    return nil
end

for _, fileName in ipairs({"iron.dat", "bee.dat", "vitality_star.dat", "crit_star.dat", "diamond.dat", "emerald.dat"}) do
    loadImage(fileName)
end

local function createESP(obj, espType, config)
    local id = getUniqueIdentifier(obj)
    if trackedObjects[id] then return end

    local part = config.getTarget(obj)
    if not part then return end

    local finalColor = type(config.color) == "function" and config.color(obj) or config.color
    local finalText = type(config.text) == "function" and config.text(obj) or config.text

    local imageFile = getImageFile(espType, obj)
    local isImageESP = (imageFile ~= nil)
    local isDropItem = (espType == "iron" or espType == "diamond" or espType == "emerald")
    local box = nil
    local text = nil
    local amountText = nil
    local kitText = nil
    local equippedText = nil
    local img = nil
    local bg = nil

    if isImageESP then
        local pic = cachedImages[imageFile]
        if not pic or #pic == 0 then
            return
        end

        img = Drawing.new("Image")
        img.Visible = false
        img.Data = pic
        img.Size = Vector2.new(44, 44)
        img.Rounding = 4
        img.ZIndex = 5

        bg = Drawing.new("Square")
        bg.Visible = false
        bg.Filled = true
        bg.Color = Color3.fromRGB(0, 0, 0)
        bg.Transparency = 0.5
        bg.Corner = 10
        bg.ZIndex = 4

        if isDropItem then
            amountText = Drawing.new("Text")
            amountText.Visible = false
            amountText.Color = Color3.fromRGB(230, 230, 230)
            amountText.Size = 12
            amountText.Center = true
            amountText.Outline = true
        end
    else
        box = Drawing.new("Square")
        box.Visible = false
        box.Color = finalColor
        box.Thickness = 1.5
        box.Filled = false

        text = Drawing.new("Text")
        text.Visible = false
        text.Text = finalText
        text.Color = Color3.fromRGB(255, 255, 255)
        text.Size = 14
        text.Center = true
        text.Outline = true

        amountText = Drawing.new("Text")
        amountText.Visible = false
        amountText.Color = Color3.fromRGB(230, 230, 230)
        amountText.Size = 12
        amountText.Center = true
        amountText.Outline = true

        kitText = Drawing.new("Text")
        kitText.Visible = false
        kitText.Color = Color3.fromRGB(255, 215, 0)
        kitText.Size = 12
        kitText.Center = true
        kitText.Outline = true

        equippedText = Drawing.new("Text")
        equippedText.Visible = false
        equippedText.Color = Color3.fromRGB(175, 238, 238)
        equippedText.Size = 12
        equippedText.Center = true
        equippedText.Outline = true
    end

    trackedObjects[id] = { 
        box = box, 
        text = text, 
        amountText = amountText,
        kitText = kitText,
        equippedText = equippedText,
        img = img,
        bg = bg,
        isImage = isImageESP,
        imageFile = imageFile,
        imgSize = img and img.Size,
        imageSet = false,
        part = part, 
        obj = obj, 
        espType = espType 
    }
end

local function removeESP(id)
    local data = trackedObjects[id]
    if data then
        if data.box then data.box:Remove() end
        if data.text then data.text:Remove() end
        if data.amountText then data.amountText:Remove() end
        if data.kitText then data.kitText:Remove() end
        if data.equippedText then data.equippedText:Remove() end
        if data.img then data.img:Remove() end
        if data.bg then data.bg:Remove() end
        trackedObjects[id] = nil
    end
end

local function scanESP()
    local currentScanIds = {}

    local workspaceChildren = Workspace:GetChildren()
    for i = 1, #workspaceChildren do
        local child = workspaceChildren[i]
        for espType, config in pairs(espConfigs) do
            if config.validator(child) then
                createESP(child, espType, config)
                currentScanIds[getUniqueIdentifier(child)] = true
                break
            end
        end
    end

    local itemDropsFolder = Workspace:FindFirstChild("ItemDrops")
    if itemDropsFolder then
        local items = itemDropsFolder:GetChildren()
        for i = 1, #items do
            local item = items[i]
            for espType, config in pairs(espConfigs) do
                if config.validator(item) then
                    createESP(item, espType, config)
                    currentScanIds[getUniqueIdentifier(item)] = true
                    break
                end
            end
        end
    end

    for id, data in pairs(trackedObjects) do
        if not currentScanIds[id] or not data.obj or not data.obj.Parent then
            removeESP(id)
        end
    end
end

local function hideESP(data)
    if data.box then data.box.Visible = false end
    if data.text then data.text.Visible = false end
    if data.amountText then data.amountText.Visible = false end
    if data.kitText then data.kitText.Visible = false end
    if data.equippedText then data.equippedText.Visible = false end
    if data.img then data.img.Visible = false end
    if data.bg then data.bg.Visible = false end
end

RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    for id, data in pairs(trackedObjects) do
        if not data.part or not data.part.Parent or not data.obj or not data.obj.Parent then
            removeESP(id)
            continue
        end

        if data.obj == char or data.obj.Name == LocalPlayer.Name then
            hideESP(data)
            continue
        end

        if not settings[data.espType] then
            hideESP(data)
            continue
        end

        if not root then
            hideESP(data)
            continue
        end

        local part = data.part
        local ok, wp, pos, onScreen, tlX, tlY, brX, brY = pcall(function()
            local w = part.Position
            local s = part.Size
            local screenPos, onScr = WorldToScreen(w)
            if data.isImage then
                return w, screenPos, onScr, 0, 0, 0, 0
            end
            local tl = WorldToScreen((part.CFrame * CFrame.new(-s.X/2, s.Y/2, 0)).Position)
            local br = WorldToScreen((part.CFrame * CFrame.new(s.X/2, -s.Y/2, 0)).Position)
            return w, screenPos, onScr, tl.X, tl.Y, br.X, br.Y
        end)

        if not ok then
            removeESP(id)
            continue
        end

        if not onScreen or (wp - root.Position).Magnitude > settings.Distance then
            hideESP(data)
            continue
        end

        local width = math.abs(tlX - brX)
        local height = math.abs(tlY - brY)

        if data.isImage then
            if not data.imageSet then
                local pic = cachedImages[data.imageFile]
                if pic and #pic > 0 then
                    data.img.Data = pic
                end
                data.imageSet = true
            end

            local size = data.imgSize
            data.bg.Size = Vector2.new(size.X + 10, size.Y + 10)
            data.bg.Position = Vector2.new(pos.X - (size.X + 10) * 0.5, pos.Y - (size.Y + 10) * 0.5)
            data.bg.Visible = true

            data.img.Position = Vector2.new(pos.X - size.X * 0.5, pos.Y - size.Y * 0.5)
            data.img.Visible = true

            if settings.Amount and (data.espType == "iron" or data.espType == "diamond" or data.espType == "emerald") then
                local amount = data.obj:GetAttribute("Amount") or 1
                data.amountText.Text = "x" .. tostring(amount)
                data.amountText.Position = Vector2.new(pos.X, pos.Y + size.Y * 0.5 + 12)
                data.amountText.Visible = true
            end
        else
            data.box.Size = Vector2.new(width, height)
            data.box.Position = Vector2.new(pos.X - width/2, pos.Y - height/2)
            data.box.Visible = true

            data.text.Position = Vector2.new(pos.X, pos.Y - height/2 - 16)
            data.text.Visible = true

            local currentBottomOffset = height / 2 + 4

            if settings.Amount and (data.espType == "iron" or data.espType == "diamond" or data.espType == "emerald") then
                local amount = data.obj:GetAttribute("Amount") or 1
                data.amountText.Text = "x" .. tostring(amount)
                data.amountText.Position = Vector2.new(pos.X, pos.Y + currentBottomOffset)
                data.amountText.Visible = true
                currentBottomOffset = currentBottomOffset + 14
            end

            if settings.ShowKit and data.espType == "Player" then
                local kitName = getPlayerKit(data.obj)
                data.kitText.Text = "Kit: " .. string.upper(string.sub(kitName, 1, 1)) .. string.sub(kitName, 2)
                data.kitText.Position = Vector2.new(pos.X, pos.Y + currentBottomOffset)
                data.kitText.Visible = true
                currentBottomOffset = currentBottomOffset + 14
            end

            if settings.ShowEquipped and data.espType == "Player" then
                local itemName = getEquippedItem(data.obj)
                data.equippedText.Text = "Holding: " .. itemName
                data.equippedText.Position = Vector2.new(pos.X, pos.Y + currentBottomOffset)
                data.equippedText.Visible = true
            end
        end
    end
end)

local canRaycast = false
pcall(function()
    local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(0, 1, 0))
    canRaycast = true
end)

local function getAttackData()
    local char = LocalPlayer.Character
    local weapon = nil

    if char then
        local equippedName = getEquippedItem(char)
        if equippedName and equippedName ~= "None" then
            local invItem = getInventoryItem(equippedName)
            if invItem and invItem.tool then
                weapon = invItem.tool
            end
        end
    end

    if not weapon then
        weapon = getEquippedWeaponDirect()
    end

    if not weapon and char then
        weapon = char:FindFirstChildWhichIsA("Tool")
    end

    if settings.LimitToItems and not weapon then
        return false
    end

    return weapon
end

local nextKillAuraTime = 0
local function runKillAura()
    if not settings.Killaura then return end

    local now = tick()
    if now < nextKillAuraTime then return end
    nextKillAuraTime = now + 0.1

    if settings.RequireMouseDown and not ismouse1pressed() then 
        Attacking = false
        return
    end

    local weapon = getAttackData()
    Attacking = false
    
    if weapon then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if root then
            local localfacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
            local targetsList = {}

            for _, data in pairs(trackedObjects) do
                if data.part and data.part.Parent then
                    if data.obj == char or data.obj.Name == LocalPlayer.Name then
                        continue
                    end

                    local isPlayer = (data.espType == "Player")
                    local isEntity = (data.espType == "Entity")

                    if isPlayer or (isEntity and settings.TargetEntities) then
                        local humanoid = data.part.Parent:FindFirstChildWhichIsA("Humanoid")
                        if humanoid and humanoid.Health > 0 then
                            if isPlayer and settings.TeamCheck then
                                local targetPlrInstance = Players:FindFirstChild(data.obj.Name)
                                if targetPlrInstance and targetPlrInstance.Team == LocalPlayer.Team then
                                    continue
                                end
                            end

                            local delta = (data.part.Position - root.Position)
                            local dist = delta.Magnitude

                            if dist <= settings.SwingRange then
                                local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
                                if angle <= (math.rad(settings.AngleValue) / 2) then
                                    table.insert(targetsList, {
                                        instance = data.part.Parent,
                                        part = data.part,
                                        distance = dist
                                    })
                                end
                            end
                        end
                    end
                end
            end

            table.sort(targetsList, function(a, b) return a.distance < b.distance end)

            for _, targetData in ipairs(targetsList) do
                Attacking = true

                if settings.FaceTarget then
                    local vec = targetData.part.Position * Vector3.new(1, 0, 1)
                    local targetCFrame = CFrame.lookAt(root.Position, Vector3.new(vec.X, root.Position.Y, vec.Z))
                    root.CFrame = root.CFrame:Lerp(targetCFrame, 0.25)
                end

                local wallBlocked = false
                if settings.WallCheck and canRaycast then
                    local rayDir = (targetData.part.Position - root.Position)
                    local ok, hit = pcall(function()
                        return workspace:Raycast(root.Position + rayDir.Unit * 1.5, rayDir)
                    end)
                    if ok and hit and hit.Instance then
                        local inst = hit.Instance
                        if inst and not inst:IsDescendantOf(targetData.instance) and not inst:IsDescendantOf(char) then
                            wallBlocked = true
                        end
                    end
                end

                if not wallBlocked and targetData.distance <= settings.SwingRange then
                    local dir = CFrame.lookAt(root.Position, targetData.part.Position).LookVector
                    local pos = root.Position + dir * math.max(targetData.distance - 14.399, 0)

                    SwordHitEvent:FireServer({
                        chargedAttack = { chargeRatio = 0 },
                        entityInstance = targetData.instance,
                        validate = {
                            selfPosition = { value = pos },
                            targetPosition = { value = targetData.part.Position }
                        },
                        weapon = weapon
                    })
                end
            end
        end
    end
end

local function runAutoKit()
    if settings.AutoKit then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if root then
            for _, data in pairs(trackedObjects) do
                if data.part and data.part.Parent then
                    local dist = (data.part.Position - root.Position).Magnitude
                    if dist <= settings.AutoKitRange then
                        if data.espType == "Metal" then
                            local metalId = data.obj:GetAttribute("Id")
                            if metalId then
                                CollectEvent:FireServer({
                                    id = metalId
                                })
                            end
                        elseif data.espType == "Bee" then
                            local beeId = data.obj:GetAttribute("BeeId")
                            if beeId then
                                PickUpBeeEvent:FireServer({
                                    beeId = beeId
                                })
                            end
                        elseif data.espType == "Star" then
                            local starId = data.obj:GetAttribute("Id")
                            if starId then
                                CollectEvent:FireServer({
                                    id = starId,
                                    collectableName = data.obj.Name
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end

local cachedLowestPoint = -30
local function updateLowestPoint()
    local collections = {Workspace:FindFirstChild("Map"), Workspace:FindFirstChild("MapSpawns")}
    local foundLowest = math.huge
    
    local ok = pcall(function()
        for _, folder in ipairs(collections) do
            if folder then
                local descendants = folder:GetDescendants()
                for i = 1, #descendants do
                    local v = descendants[i]
                    if v:IsA("BasePart") then
                        local size = v.Size
                        local pos = v.Position
                        local point = (pos.Y - (size.Y / 2)) - 15 
                        if point < foundLowest then
                            foundLowest = point
                        end
                    end
                end
            end
        end
    end)

    if ok and foundLowest ~= math.huge and foundLowest < 100 then
        cachedLowestPoint = foundLowest
    else
        cachedLowestPoint = -30 
    end
end

local dropCooldownUntil = 0
local function runAutoVoidDrop()
    if settings.AutoVoidDrop and tick() >= dropCooldownUntil then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if root then
            local currentY = root.Position.Y
            local threshold = cachedLowestPoint or -30

            if currentY < threshold then
                local balloonCount = LocalPlayer:GetAttribute("InflatedBalloons") or 0
                local hasBalloonInInventory = getInventoryItem("balloon")
                local hasOwlLift = root:FindFirstChild("OwlLiftForce")

                if not (balloonCount > 0 or hasBalloonInInventory) and not (settings.OwlCheck and hasOwlLift) then
                    local itemsToDrop = {"iron", "diamond", "emerald", "gold"}
                    
                    for _, itemName in ipairs(itemsToDrop) do
                        local itemData = getInventoryItem(itemName)
                        if itemData then
                            DropItemRemote:FireServer({
                                item = itemData.tool,
                                amount = itemData.amount
                            })
                        end
                    end

                    dropCooldownUntil = tick() + 2
                end
            end
        end
    end
end

local canControlInput = (type(mouse1press) == "function" and type(mouse1release) == "function")
local fishingInputDown = false

local function findMinigameApp()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then return nil end
    local actionBarScreen = gui:FindFirstChild("ActionBarScreenGui")
    if not actionBarScreen then return nil end
    local actionBar = actionBarScreen:FindFirstChild("ActionBar")
    if not actionBar then return nil end
    return actionBar:FindFirstChild("FishingMinigameApp")
end

local function releaseFishingInput()
    if fishingInputDown then
        pcall(function() mouse1release() end)
        fishingInputDown = false
    end
end

local function runAutoFisher()
    if not settings.Fishing then
        releaseFishingInput()
        return
    end

    local app = findMinigameApp()

    if not app then
        releaseFishingInput()
        return
    end

    if not canControlInput then return end

    pcall(function()
        local marker = app:FindFirstChild("Marker", true)
        local zone = app:FindFirstChild("FishZone", true)
        if not marker or not zone then return end

        local mCenter = marker.AbsolutePosition.X + marker.AbsoluteSize.X * 0.5
        local zCenter = zone.AbsolutePosition.X + zone.AbsoluteSize.X * 0.5

        if mCenter < zCenter - 6 then
            if not fishingInputDown then
                mouse1press()
                fishingInputDown = true
            end
        elseif mCenter > zCenter + 6 then
            if fishingInputDown then
                mouse1release()
                fishingInputDown = false
            end
        end
    end)
end

killAuraCategory:Toggle("Enabled", settings.Killaura, function(state) settings.Killaura = state saveConfig() end)
killAuraCategory:Toggle("Target Entities", settings.TargetEntities, function(state) settings.TargetEntities = state saveConfig() end)
killAuraCategory:Toggle("Team Check", settings.TeamCheck, function(state) settings.TeamCheck = state saveConfig() end)
killAuraCategory:Slider("Swing Range", settings.SwingRange, 1, 1, 28, function(value) settings.SwingRange = value saveConfig() end)
killAuraCategory:Slider("Max Angle", settings.AngleValue, 1, 1, 360, function(value) settings.AngleValue = value saveConfig() end)
killAuraCategory:Toggle("Require Mouse Down", settings.RequireMouseDown, function(state) settings.RequireMouseDown = state saveConfig() end)
killAuraCategory:Toggle("No Swing", settings.NoSwing, function(state) settings.NoSwing = state saveConfig() end)
killAuraCategory:Toggle("Face Target", settings.FaceTarget, function(state) settings.FaceTarget = state saveConfig() end)
killAuraCategory:Toggle("Limit to Items", settings.LimitToItems, function(state) settings.LimitToItems = state saveConfig() end)
killAuraCategory:Toggle("SwingOnly", settings.SwingOnly, function(state) settings.SwingOnly = state saveConfig() end)
killAuraCategory:Toggle("Wall Check", settings.WallCheck, function(state) settings.WallCheck = state saveConfig() end)

if autoKitCategory then
    autoKitCategory:Toggle("Enabled", settings.AutoKit, function(state) settings.AutoKit = state saveConfig() end)
    autoKitCategory:Slider("Collection Range", settings.AutoKitRange, 5, 1, 20, function(value) settings.AutoKitRange = value saveConfig() end)
end

autoVoidDropCategory:Toggle("Enabled", settings.AutoVoidDrop, function(state) settings.AutoVoidDrop = state saveConfig() end)
autoVoidDropCategory:Toggle("Owl Check", settings.OwlCheck, function(state) settings.OwlCheck = state saveConfig() end)
autoFishingCategory:Toggle("Enabled", settings.Fishing, function(state) settings.Fishing = state saveConfig() end)

gameEsp:Toggle("Player ESP", settings.Player, function(state) settings.Player = state saveConfig() end)
gameEsp:Toggle("Bed ESP", settings.Bed, function(state) settings.Bed = state saveConfig() end)
gameEsp:Toggle("Entity ESP", settings.Entity, function(state) settings.Entity = state saveConfig() end)
gameEsp:Toggle("Show Kit", settings.ShowKit, function(state) settings.ShowKit = state saveConfig() end)
gameEsp:Toggle("Show Equipped", settings.ShowEquipped, function(state) settings.ShowEquipped = state saveConfig() end)

kitEsp:Toggle("Metal ESP", settings.Metal, function(state) settings.Metal = state saveConfig() end)
kitEsp:Toggle("Bee ESP", settings.Bee, function(state) settings.Bee = state saveConfig() end)
kitEsp:Toggle("Eldertree ESP", settings.Eldertree, function(state) settings.Eldertree = state saveConfig() end)
kitEsp:Toggle("Star ESP", settings.Star, function(state) settings.Star = state saveConfig() end)

itemEsp:Toggle("Iron ESP", settings.iron, function(state) settings.iron = state saveConfig() end)
itemEsp:Toggle("Diamond ESP", settings.diamond, function(state) settings.diamond = state saveConfig() end)
itemEsp:Toggle("Emerald ESP", settings.emerald, function(state) settings.emerald = state saveConfig() end)
itemEsp:Toggle("Show Amount", settings.Amount, function(state) settings.Amount = state saveConfig() end)

espOptions:Toggle("Visible Only", settings.Visible, function(state) settings.Visible = state saveConfig() end)
espOptions:Slider("Distance", settings.Distance, 100, 1, 2000, function(value) settings.Distance = value saveConfig() end)

local nextScanTime = 0
local nextAutoKitTime = 0
local nextVoidDropTime = 0
local nextLowestPointTime = 0

task.spawn(function()
    while true do
        local now = tick()

        if now >= nextScanTime then
            nextScanTime = now + 1.0
            scanESP()
        end

        if now >= nextAutoKitTime then
            nextAutoKitTime = now + 0.1
            runAutoKit()
        end

        if now >= nextVoidDropTime then
            nextVoidDropTime = now + 0.2
            runAutoVoidDrop()
        end

        if now >= nextLowestPointTime and settings.AutoVoidDrop then
            nextLowestPointTime = now + 10
            updateLowestPoint()
        end

        runAutoFisher()

        runKillAura()

        task.wait(1 / 60)
    end
end)
