local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/rconsoIe2/MatchaLuauVM/refs/heads/main/Libraries/RiseUI.lua"))() or RiseUI

local win = Lib:CreateWindow({ 
    title = "Rise", 
    size = Vector2.new(560, 400) 
})

local blatantTab = win:Tab("Blatant")
local blatantSec = blatantTab:Section("Combat", "Left")

local tab = win:Tab("Utility")
local sec = tab:Section("ESP", "Left")
local gameEsp = sec:Category("Game ESP")
local kitEsp = sec:Category("Kit ESP")
local itemEsp = sec:Category("Items ESP")
local espOptions = sec:Category("Options")

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

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
    Distance = 500
}

local trackedObjects = {}

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

local espConfigs = {
    Player = {
        validator = function(obj)
            if obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") and obj:FindFirstChild("Humanoid") then
                local plr = Players:FindFirstChild(obj.Name)
                return plr ~= nil and plr ~= LocalPlayer and obj ~= LocalPlayer.Character
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
                return Players:FindFirstChild(obj.Name) == nil and obj ~= LocalPlayer.Character
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

local function isVisible(targetPart, origin)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    raycastParams.IgnoreWater = true
    
    local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    local result = Workspace:Raycast(origin, direction, raycastParams)
    
    return result == nil
end

local function createESP(obj, espType, config)
    local id = getUniqueIdentifier(obj)
    if trackedObjects[id] then return end

    local part = config.getTarget(obj)
    if not part then return end

    local finalColor = type(config.color) == "function" and config.color(obj) or config.color
    local finalText = type(config.text) == "function" and config.text(obj) or config.text

    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = finalColor
    box.Thickness = 1.5
    box.Filled = false

    local text = Drawing.new("Text")
    text.Visible = false
    text.Text = finalText
    text.Color = Color3.fromRGB(255, 255, 255)
    text.Size = 14
    text.Center = true
    text.Outline = true

    local amountText = Drawing.new("Text")
    amountText.Visible = false
    amountText.Color = Color3.fromRGB(230, 230, 230)
    amountText.Size = 12
    amountText.Center = true
    amountText.Outline = true

    local kitText = Drawing.new("Text")
    kitText.Visible = false
    kitText.Color = Color3.fromRGB(255, 215, 0)
    kitText.Size = 12
    kitText.Center = true
    kitText.Outline = true

    local equippedText = Drawing.new("Text")
    equippedText.Visible = false
    equippedText.Color = Color3.fromRGB(175, 238, 238)
    equippedText.Size = 12
    equippedText.Center = true
    equippedText.Outline = true

    trackedObjects[id] = { 
        box = box, 
        text = text, 
        amountText = amountText,
        kitText = kitText,
        equippedText = equippedText,
        part = part, 
        obj = obj, 
        espType = espType 
    }
end

local function removeESP(id)
    if trackedObjects[id] then
        trackedObjects[id].box:Remove()
        trackedObjects[id].text:Remove()
        trackedObjects[id].amountText:Remove()
        trackedObjects[id].kitText:Remove()
        trackedObjects[id].equippedText:Remove()
        trackedObjects[id] = nil
    end
end

task.spawn(function()
    while true do
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

        task.wait(1.0)
    end
end)

RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    for id, data in pairs(trackedObjects) do
        if data.obj == char then
            data.box.Visible = false
            data.text.Visible = false
            data.amountText.Visible = false
            data.kitText.Visible = false
            data.equippedText.Visible = false
            continue
        end

        if settings[data.espType] and data.part and data.part.Parent and root then
            local distance = (data.part.Position - root.Position).Magnitude
            
            if distance <= settings.Distance then
                local passVisibility = true
                if settings.Visible then
                    passVisibility = isVisible(data.part, root.Position)
                end

                if passVisibility then
                    local pos, onScreen = WorldToScreen(data.part.Position)
                    if onScreen then
                        local size = data.part.Size
                        local topLeft, tlOnScreen = WorldToScreen((data.part.CFrame * CFrame.new(-size.X/2, size.Y/2, 0)).Position)
                        local bottomRight, brOnScreen = WorldToScreen((data.part.CFrame * CFrame.new(size.X/2, -size.Y/2, 0)).Position)
                        
                        local width = math.abs(topLeft.X - bottomRight.X)
                        local height = math.abs(topLeft.Y - bottomRight.Y)
                        
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
                        else
                            data.amountText.Visible = false
                        end

                        if settings.ShowKit and data.espType == "Player" then
                            local kitName = getPlayerKit(data.obj)
                            data.kitText.Text = "Kit: " .. string.upper(string.sub(kitName, 1, 1)) .. string.sub(kitName, 2)
                            data.kitText.Position = Vector2.new(pos.X, pos.Y + currentBottomOffset)
                            data.kitText.Visible = true
                            currentBottomOffset = currentBottomOffset + 14
                        else
                            data.kitText.Visible = false
                        end

                        if settings.ShowEquipped and data.espType == "Player" then
                            local itemName = getEquippedItem(data.obj)
                            data.equippedText.Text = "Holding: " .. itemName
                            data.equippedText.Position = Vector2.new(pos.X, pos.Y + currentBottomOffset)
                            data.equippedText.Visible = true
                        else
                            data.equippedText.Visible = false
                        end
                    else
                        data.box.Visible = false
                        data.text.Visible = false
                        data.amountText.Visible = false
                        data.kitText.Visible = false
                        data.equippedText.Visible = false
                    end
                else
                    data.box.Visible = false
                    data.text.Visible = false
                    data.amountText.Visible = false
                    data.kitText.Visible = false
                    data.equippedText.Visible = false
                end
            else
                data.box.Visible = false
                data.text.Visible = false
                data.amountText.Visible = false
                data.kitText.Visible = false
                data.equippedText.Visible = false
            end
        else
            data.box.Visible = false
            data.text.Visible = false
            data.amountText.Visible = false
            data.kitText.Visible = false
            data.equippedText.Visible = false
        end
    end
end)

blatantSec:Toggle("InstaShoot", false, function(state)
    task.spawn(function()
        if not _G.InstantBowCache then
            _G.InstantBowCache = getgc({
                "CROSSBOW_FIRE_DELAY",
                "HEADHUNTER_FIRE_DELAY", 
                "fireDelaySec"
            })
        end

        local crossbowDelay = state and 0.001 or 1.25
        local headhunterDelay = state and 0.001 or 1.25
        local fireDelaySec = state and 0.001 or 0.15

        applygc(_G.InstantBowCache, "CROSSBOW_FIRE_DELAY", crossbowDelay)
        applygc(_G.InstantBowCache, "HEADHUNTER_FIRE_DELAY", headhunterDelay)
        applygc(_G.InstantBowCache, "fireDelaySec", fireDelaySec)

        if Lib.Notification or Lib.Notify then
            local notifyFunc = Lib.Notification or Lib.Notify
            notifyFunc(win, {
                title = "InstaShoot",
                content = state and "InstaShoot Enabled!" or "InstaShoot Disabled (Restored defaults)!",
                duration = 3
            })
        end
    end)
end)

gameEsp:Toggle("Player ESP", false, function(state) settings.Player = state end)
gameEsp:Toggle("Bed ESP", false, function(state) settings.Bed = state end)
gameEsp:Toggle("Entity ESP", false, function(state) settings.Entity = state end)
gameEsp:Toggle("Show Kit", false, function(state) settings.ShowKit = state end)
gameEsp:Toggle("Show Equipped", false, function(state) settings.ShowEquipped = state end)

kitEsp:Toggle("Metal ESP", false, function(state) settings.Metal = state end)
kitEsp:Toggle("Bee ESP", false, function(state) settings.Bee = state end)
kitEsp:Toggle("Eldertree ESP", false, function(state) settings.Eldertree = state end)
kitEsp:Toggle("Star ESP", false, function(state) settings.Star = state end)

itemEsp:Toggle("Iron ESP", false, function(state) settings.iron = state end)
itemEsp:Toggle("Diamond ESP", false, function(state) settings.diamond = state end)
itemEsp:Toggle("Emerald ESP", false, function(state) settings.emerald = state end)
itemEsp:Toggle("Show Amount", false, function(state) settings.Amount = state end)

espOptions:Toggle("Visible Only", false, function(state) settings.Visible = state end)
espOptions:Slider("Distance", 500, 100, 1, 2000, function(value) settings.Distance = value end)
