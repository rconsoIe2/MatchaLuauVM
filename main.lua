local HttpService = game:GetService("HttpService")

local API_BASE = "https://api.github.com/repos/rconsoIe2/MatchaLuauVM/contents"

local function httpGet(url)
    return pcall(function()
        return game:HttpGet(url)
    end)
end

local function listRepoDir(repoPath)
    local url = API_BASE
    if repoPath and #repoPath > 0 then
        url = API_BASE .. "/" .. repoPath
    end

    local ok, body = httpGet(url)
    if not ok or type(body) ~= "string" or #body == 0 then
        return nil
    end

    local decoded
    local ok2 = pcall(function()
        decoded = HttpService:JSONDecode(body)
    end)
    if ok2 and type(decoded) == "table" then
        return decoded
    end
    return nil
end

local allowedExts = { dat = true, lua = true, luau = true, json = true, cfg = true, txt = true, ini = true }

local function findMatchingBrace(source, openIdx)
    local depth = 0
    local inStr = false
    local strChar
    for i = openIdx, #source do
        local c = source:sub(i, i)
        if inStr then
            if c == strChar then
                inStr = false
            end
        elseif c == '"' or c == "'" then
            inStr = true
            strChar = c
        elseif c == "{" then
            depth = depth + 1
        elseif c == "}" then
            depth = depth - 1
            if depth == 0 then
                return i
            end
        end
    end
    return nil
end

local function parseSettingsBlock(source)
    local mStart, mEnd = source:find("settings%s*=%s*{")
    if not mEnd then
        return nil
    end
    local closeIdx = findMatchingBrace(source, mEnd)
    if not closeIdx then
        return nil
    end

    local inner = source:sub(mEnd + 1, closeIdx - 1)
    local entries = {}
    local depth = 0
    local inStr = false
    local strChar
    local startIdx = 1
    for i = 1, #inner do
        local c = inner:sub(i, i)
        local isEnd = (i == #inner)
        local split = false
        if inStr then
            if c == strChar then
                inStr = false
            end
        elseif c == '"' or c == "'" then
            inStr = true
            strChar = c
        elseif c == "{" then
            depth = depth + 1
        elseif c == "}" then
            depth = depth - 1
        elseif c == "," and depth == 0 then
            split = true
        end

        if split or isEnd then
            local part = inner:sub(startIdx, split and (i - 1) or i)
            local chunk = part:gsub("^%s+", ""):gsub("[%s,]+$", "")
            if #chunk > 0 then
                local key, value = chunk:match("^([%a_][%w_]*)%s*=%s*(.-)$")
                if key and value and #value > 0 then
                    table.insert(entries, { key = key, value = value })
                end
            end
            startIdx = i + 1
        end
    end
    return entries
end

local function mergeSettings(remoteSrc, localSrc)
    local mStart, mEnd = remoteSrc:find("settings%s*=%s*{")
    if not mEnd then
        return remoteSrc
    end
    local closeIdx = findMatchingBrace(remoteSrc, mEnd)
    if not closeIdx then
        return remoteSrc
    end

    local remoteEntries = parseSettingsBlock(remoteSrc)
    if not remoteEntries or #remoteEntries == 0 then
        return remoteSrc
    end

    local localEntries = parseSettingsBlock(localSrc) or {}
    local localMap = {}
    for _, entry in ipairs(localEntries) do
        localMap[entry.key] = entry.value
    end

    local lines = {}
    for _, entry in ipairs(remoteEntries) do
        local value = localMap[entry.key] or entry.value
        table.insert(lines, "    " .. entry.key .. " = " .. value .. ",")
    end

    local merged = remoteSrc:sub(1, mEnd - 1) .. "{\n" .. table.concat(lines, "\n") .. "\n}" .. remoteSrc:sub(closeIdx + 1)
    return merged
end

local function syncDir(repoPath, localBase)
    local entries = listRepoDir(repoPath)
    if not entries then return end

    for _, entry in ipairs(entries) do
        if entry.type == "file" and entry.download_url then
            local name = entry.name
            local ext = name and name:match("%.([%w]+)$")
            if ext and allowedExts[ext:lower()] then
                local ok, remote = httpGet(entry.download_url)
                if ok and type(remote) == "string" then
                    local localPath = localBase .. name
                    local localContent = ""
                    if isfile(localPath) then
                        pcall(function()
                            localContent = readfile(localPath)
                        end)
                    end
                    local writeContent = remote
                    if repoPath == "Scripts" and name:lower():match("%.lua$") and #localContent > 0 then
                        writeContent = mergeSettings(remote, localContent)
                    end
                    if writeContent ~= localContent then
                        writefile(localPath, writeContent)
                    end
                end
            end
        end
    end
end

if not isfolder("rise/configs") then makefolder("rise/configs") end

if not _G.developer then
    if not isfolder("rise") then makefolder("rise") end
    if not isfolder("rise/assets") then makefolder("rise/assets") end
    if not isfolder("rise/libraries") then makefolder("rise/libraries") end
    if not isfolder("rise/scripts") then makefolder("rise/scripts") end

    syncDir(nil, "rise/")
    syncDir("Assets", "rise/assets/")
    syncDir("Libraries", "rise/libraries/")
    syncDir("Scripts", "rise/scripts/")
end

local placeId = tostring(game.PlaceId)
local perGamePath = "rise/scripts/" .. placeId .. ".lua"

local scriptSource = ""
local scriptPath = perGamePath
if isfile(perGamePath) then
    pcall(function()
        scriptSource = readfile(perGamePath)
    end)
end

if #scriptSource == 0 and isfile("rise/scripts/Bedwars.lua") then
    scriptPath = "rise/scripts/Bedwars.lua"
    pcall(function()
        scriptSource = readfile(scriptPath)
    end)
end

if #scriptSource > 0 then
    _G.loadedFromMain = true
    loadstring(scriptSource)()
end
