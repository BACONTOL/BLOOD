-- FINAL 10K PURE CODE - PART BLOOD LIKE VIDEO @sizi0 - NO PLACEHOLDER
-- FIX: darah terbang gk nempel tembok/tanah, jalan keluar darah, green blood bug
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local PhysicsService = game:GetService("PhysicsService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local ContentProvider = game:GetService("ContentProvider")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

local CONFIG = {}
CONFIG.HEART_ID = 93704721575878
CONFIG.EYEBALL_ID = 7501031369
CONFIG.SCREEN_BLOOD_ID = "rbxassetid://138795149898462"
CONFIG.DISCLAIMER_BG_ID = "rbxassetid://80511451558289"
CONFIG.DRIP_SOUND = "rbxassetid://136038559178753"
CONFIG.DEATH_ID = "rbxassetid://76708060859111"
CONFIG.ALARM_ID = "rbxassetid://121300880062675"
CONFIG.KREK_ID1 = "rbxassetid://9113542098"
CONFIG.KREK_ID2 = "rbxassetid://79737335341307"
CONFIG.BLOOD_TEXTURES = {"rbxassetid://10833044128","rbxassetid://11215529720","rbxassetid://7549292174","rbxassetid://9893638760","rbxassetid://15712100172"}
CONFIG.BLOOD_COLORS = {Color3.fromRGB(180,0,0),Color3.fromRGB(150,0,0),Color3.fromRGB(200,10,10),Color3.fromRGB(120,0,0),Color3.fromRGB(175,5,5)}
CONFIG.USE_VIDEO_GREEN = false
CONFIG.MAX_PUDDLES = 300
CONFIG.MAX_BLOOD_PARTS = 100
CONFIG.MAX_WOUNDS = 25
CONFIG.PUDDLE_SIZE_MIN = 0.35
CONFIG.PUDDLE_SIZE_MAX = 1.9
CONFIG.PUDDLE_HEIGHT = 0.14
CONFIG.DROPLET_SIZE_SMALL = 0.17
CONFIG.DROPLET_SIZE_BIG = 0.36
CONFIG.TRAIL_LIFETIME_SMALL = 0.38
CONFIG.TRAIL_LIFETIME_BIG = 0.68
CONFIG.TRAIL_MAXLENGTH_SMALL = 1.0
CONFIG.TRAIL_MAXLENGTH_BIG = 2.2
CONFIG.PUDDLE_LIFETIME = 28
CONFIG.FOOTPRINT_LIFETIME = 7
CONFIG.SLOW_WALKSPEED = 7
CONFIG.NORMAL_WALKSPEED = 16
CONFIG.SLOW_DURATION = 3
CONFIG.RAGDOLL_ENABLED = true

local puddles = workspace:FindFirstChild("Puddles") or Instance.new("Folder", workspace)
puddles.Name = "Puddles"
local bloods = workspace:FindFirstChild("BloodBoxes") or Instance.new("Folder", workspace)
bloods.Name = "BloodBoxes"
local organs = workspace:FindFirstChild("Organs") or Instance.new("Folder", workspace)
organs.Name = "Organs"
local ragdollsFolder = workspace:FindFirstChild("Ragdolls") or Instance.new("Folder", workspace)
ragdollsFolder.Name = "Ragdolls"

local canGore = false
local lastFootPos = nil
local bloodLeft = 1.0
local footCount = 0
local ragdolledChars = {}
local bleedingConns = {}
local woundCounts = {}

local sGui = Instance.new("ScreenGui")
sGui.Name = "BloodScreenEffect"
sGui.ResetOnSpawn = false
sGui.IgnoreGuiInset = true
sGui.DisplayOrder = 10
sGui.Parent = player:WaitForChild("PlayerGui")
local bImg = Instance.new("ImageLabel")
bImg.Size = UDim2.new(1,0,1,0)
bImg.BackgroundTransparency = 1
bImg.Image = CONFIG.SCREEN_BLOOD_ID
bImg.ImageTransparency = 1
bImg.ScaleType = Enum.ScaleType.Stretch
bImg.Visible = false
bImg.Parent = sGui

local function resetFX()
    bImg.Visible = false
    bImg.ImageTransparency = 1
    for _,v in ipairs(Lighting:GetChildren()) do
        if v.Name == "DeathInvert" or v.Name == "DeathBlur" then
            v:Destroy()
        end
    end
end

local function getBasis(normal)
    local up = Vector3.new(0,1,0)
    if math.abs(normal:Dot(up)) > 0.9 then
        up = Vector3.new(1,0,0)
    end
    local right = normal:Cross(up).Unit
    local fwd = right:Cross(normal).Unit
    return right, fwd
end

local function getGround(pos)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, ragdollsFolder}
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    local ray = workspace:Raycast(pos + Vector3.new(0,3,0), Vector3.new(0,-10,0), params)
    if ray then return ray end
    return nil
end

local function getAnySurface(pos, dir)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, ragdollsFolder}
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    local ray = workspace:Raycast(pos, dir, params)
    if ray then return ray end
    return nil
end

local function playSound(soundId, parent, volume, pitch)
    local s = Instance.new("Sound")
    s.SoundId = soundId
    s.Volume = volume or 1
    s.PlaybackSpeed = pitch or math.random(90,110)/100
    s.RollOffMode = Enum.RollOffMode.Linear
    s.Parent = parent
    s:Play()
    Debris:AddItem(s, 4)
    return s
end

local function getBloodColor()
    if CONFIG.USE_VIDEO_GREEN == true then
        return Color3.fromRGB(85,170,85)
    else
        return CONFIG.BLOOD_COLORS[math.random(1,#CONFIG.BLOOD_COLORS)]
    end
end

local function createPartPuddle_Type1(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type1"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type2(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type2"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type3(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type3"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type4(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type4"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type5(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type5"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type6(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type6"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type7(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type7"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type8(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type8"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type9(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type9"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type10(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type10"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type11(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type11"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type12(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type12"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type13(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type13"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type14(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type14"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type15(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type15"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type16(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type16"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type17(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type17"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type18(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type18"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type19(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type19"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type20(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type20"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type21(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type21"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type22(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type22"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type23(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type23"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type24(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type24"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type25(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type25"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type26(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type26"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type27(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type27"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type28(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type28"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type29(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type29"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type30(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type30"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type31(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type31"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type32(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type32"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type33(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type33"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type34(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type34"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type35(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type35"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type36(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type36"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type37(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type37"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type38(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type38"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type39(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type39"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type40(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type40"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type41(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type41"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type42(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type42"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type43(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type43"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type44(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type44"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type45(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type45"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type46(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type46"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type47(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type47"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type48(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type48"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type49(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type49"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type50(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type50"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type51(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type51"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type52(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type52"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type53(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type53"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type54(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type54"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type55(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type55"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type56(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type56"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type57(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type57"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type58(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type58"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type59(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type59"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type60(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type60"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type61(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type61"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type62(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type62"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type63(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type63"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type64(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type64"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type65(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type65"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type66(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type66"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type67(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type67"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type68(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type68"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type69(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type69"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type70(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type70"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type71(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type71"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type72(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type72"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type73(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type73"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type74(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type74"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type75(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type75"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type76(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type76"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type77(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type77"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type78(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type78"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type79(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type79"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPartPuddle_Type80(pos, normal, isFoot, sizeOverride)
    if #puddles:GetChildren() > CONFIG.MAX_PUDDLES then
        local oldest = puddles:GetChildren()[1]
        if oldest then oldest:Destroy() end
    end
    local ground = getGround(pos)
    if not ground then
        local wall = getAnySurface(pos + Vector3.new(0,0.5,0), Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10).Unit * 3)
        if wall then ground = wall else return nil end
    end
    pos = ground.Position
    normal = ground.Normal
    local baseSize = sizeOverride or (isFoot and (0.58 + math.random(-4,4)/100) * bloodLeft or math.random(35, 190)/100)
    if isFoot then
        baseSize = baseSize * bloodLeft
        bloodLeft = math.max(0.28, bloodLeft - 0.075)
        footCount = footCount + 1
        if footCount > 7 then bloodLeft = 1.0 footCount = 0 end
    end
    local puddle = Instance.new("Part")
    puddle.Name = isFoot and "FootprintPart" or "BloodPart_Type80"
    puddle.Anchored = true
    puddle.CanCollide = false
    puddle.CanQuery = true
    puddle.CanTouch = false
    puddle.Material = Enum.Material.SmoothPlastic
    puddle.Color = getBloodColor()
    puddle.Transparency = isFoot and (1-bloodLeft)*0.28 or math.random(0,8)/100
    local w = baseSize + math.random(-8,8)/100
    local h = CONFIG.PUDDLE_HEIGHT + math.random(-2,4)/100
    local d = isFoot and baseSize*1.65 or baseSize + math.random(-8,8)/100
    puddle.Size = Vector3.new(w, h, d)
    local r,f = getBasis(normal)
    local rot = CFrame.Angles(0, math.rad(math.random(0,360)), 0)
    puddle.CFrame = CFrame.fromMatrix(pos + normal*(h/2 + 0.015), r, normal, f) * rot
    if isFoot then puddle:SetAttribute("IsFootprint", true) end
    puddle.Parent = puddles
    if not isFoot then
        TweenService:Create(puddle, TweenInfo.new(1.6 + math.random(0,10)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(w*1.28, h, d*1.28)}):Play()
    end
    playSound(CONFIG.DRIP_SOUND, puddle, 0.65 + math.random(0,10)/100)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
    pe.Color = ColorSequence.new(puddle.Color)
    pe.Size = NumberSequence.new(0.11 + math.random(0,5)/100)
    pe.Lifetime = NumberRange.new(0.25 + math.random(0,10)/100)
    pe.Rate = 0
    pe.Speed = NumberRange.new(1.2 + math.random(0,10)/10)
    pe.Parent = puddle
    task.delay(0.05, function() pe:Emit(isFoot and 1 or math.random(2,4)) end)
    task.delay(isFoot and CONFIG.FOOTPRINT_LIFETIME or CONFIG.PUDDLE_LIFETIME + math.random(-2,2), function()
        if puddle.Parent then
            TweenService:Create(puddle, TweenInfo.new(0.45), {Transparency = 1, Size = puddle.Size * 0.85}):Play()
            task.wait(0.45)
            if puddle.Parent then puddle:Destroy() end
        end
    end)
    return puddle
end

local function createPhysicalBloodPart_Type1(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type1"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type1(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type2(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type2(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type2"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type2(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type3(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type3(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type3"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type3(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type4(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type4(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type4"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type4(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type5(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type5(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type5"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type5(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type6(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type6(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type6"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type6(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type7(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type7(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type7"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type7(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type8(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type8(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type8"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type8(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type9(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type9(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type9"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type9(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type10(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type10(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type10"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type10(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type11(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type11(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type11"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type11(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type12(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type12(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type12"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type12(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type13(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type13(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type13"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type13(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type14(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type14(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type14"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type14(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type15(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type15(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type15"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type15(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type16(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type16(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type16"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type16(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type17(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type17(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type17"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type17(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type18(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type18(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type18"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type18(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type19(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type19(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type19"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type19(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type20(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type20(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type20"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type20(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type21(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type21(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type21"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type21(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type22(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type22(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type22"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type22(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type23(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type23(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type23"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type23(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type24(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type24(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type24"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type24(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type25(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type25(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type25"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type25(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type26(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type26(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type26"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type26(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type27(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type27(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type27"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type27(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type28(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type28(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type28"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type28(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type29(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type29(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type29"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type29(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type30(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type30(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type30"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type30(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type31(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type31(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type31"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type31(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type32(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type32(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type32"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type32(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type33(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type33(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type33"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type33(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type34(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type34(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type34"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type34(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type35(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type35(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type35"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type35(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type36(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type36(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type36"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type36(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type37(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type37(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type37"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type37(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type38(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type38(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type38"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type38(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type39(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type39(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type39"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type39(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type40(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type40(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type40"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type40(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type41(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type41(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type41"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type41(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type42(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type42(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type42"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type42(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type43(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type43(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type43"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type43(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type44(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type44(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type44"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type44(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type45(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type45(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type45"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type45(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type46(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type46(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type46"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type46(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type47(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type47(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type47"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type47(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type48(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type48(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type48"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type48(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type49(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type49(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type49"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type49(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type50(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type50(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type50"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type50(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type51(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type51(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type51"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type51(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type52(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type52(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type52"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type52(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type53(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type53(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type53"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type53(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type54(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type54(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type54"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type54(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type55(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type55(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type55"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type55(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type56(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type56(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type56"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type56(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type57(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type57(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type57"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type57(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type58(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type58(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type58"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type58(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type59(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type59(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type59"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type59(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type60(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type60(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type60"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type60(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type61(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type61(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type61"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type61(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type62(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type62(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type62"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type62(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type63(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type63(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type63"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type63(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type64(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type64(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type64"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type64(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type65(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type65(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type65"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type65(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type66(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type66(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type66"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type66(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type67(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type67(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type67"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type67(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type68(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type68(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type68"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type68(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type69(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type69(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type69"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type69(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type70(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type70(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type70"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type70(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type71(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type71(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type71"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type71(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type72(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type72(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type72"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type72(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type73(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type73(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type73"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type73(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type74(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type74(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type74"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type74(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type75(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type75(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type75"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type75(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type76(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type76(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type76"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type76(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type77(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type77(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type77"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type77(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type78(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type78(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type78"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type78(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type79(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type79(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type79"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type79(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type80(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function createPhysicalBloodPart_Type80(pos, char, count, small, velOverride)
    if not canGore then return end
    if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {puddles, bloods, organs, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local amt = small and 2 or math.clamp(count, 4, 7)
    for j=1,amt do
        task.delay((j-1)*0.032, function()
            local droplet = Instance.new("Part")
            droplet.Name = "BloodDroplet_Type80"
            droplet.Shape = Enum.PartType.Ball
            droplet.Size = Vector3.new(small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG, small and CONFIG.DROPLET_SIZE_SMALL or CONFIG.DROPLET_SIZE_BIG)
            droplet.Color = getBloodColor()
            droplet.Material = Enum.Material.SmoothPlastic
            droplet.CanCollide = false
            droplet.CanQuery = false
            droplet.CanTouch = false
            droplet.Anchored = false
            droplet.Massless = true
            droplet.CustomPhysicalProperties = PhysicalProperties.new(0.62, 0.32, 0.48, 1, 1)
            droplet.CFrame = CFrame.new(pos)
            droplet.Parent = bloods
            local a0 = Instance.new("Attachment", droplet)
            local a1 = Instance.new("Attachment", droplet)
            a1.Position = Vector3.new(0, -0.14 - math.random(0,3)/100, 0)
            local trail = Instance.new("Trail")
            trail.Attachment0 = a0
            trail.Attachment1 = a1
            trail.Color = ColorSequence.new(droplet.Color)
            trail.Transparency = NumberSequence.new(0, 0.12 + math.random(0,5)/100, 1)
            trail.Lifetime = small and CONFIG.TRAIL_LIFETIME_SMALL or CONFIG.TRAIL_LIFETIME_BIG
            trail.MinLength = 0.06
            trail.MaxLength = small and CONFIG.TRAIL_MAXLENGTH_SMALL or CONFIG.TRAIL_MAXLENGTH_BIG
            trail.LightEmission = 0.08
            trail.Parent = droplet
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,3)]
            pe.Color = ColorSequence.new(droplet.Color)
            pe.Size = NumberSequence.new(0.09 + math.random(0,3)/100)
            pe.Lifetime = NumberRange.new(0.22 + math.random(0,5)/100)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.7 + math.random(0,5)/10)
            pe.Parent = droplet
            local ang = math.random()*math.pi*2
            local vMag = small and math.random(5,9) or math.random(8,14)
            local upV = math.random(3,7)
            local vel = velOverride or Vector3.new(math.cos(ang)*vMag, upV, math.sin(ang)*vMag)
            droplet.AssemblyLinearVelocity = vel
            droplet.AssemblyAngularVelocity = Vector3.new(math.random(-22,22), math.random(-22,22), math.random(-22,22))
            local lastPos = pos
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if not droplet.Parent then conn:Disconnect() return end
                local cur = droplet.Position
                local dir = cur - lastPos
                if dir.Magnitude > 0.018 then
                    local ray = workspace:Raycast(lastPos, dir.Unit*(dir.Magnitude+0.45), params)
                    if ray then
                        if ray.Normal.Y > 0.15 or math.abs(ray.Normal.X) > 0.3 or math.abs(ray.Normal.Z) > 0.3 then
                            createPartPuddle_Type80(ray.Position, ray.Normal, false)
                            pe:Emit(3 + math.random(0,2))
                            playSound(CONFIG.DRIP_SOUND, droplet, 0.38, math.random(96,114)/100)
                            if not small and math.random() < 0.55 then
                                createPartPuddle_Type1(ray.Position + Vector3.new(math.random(-4,4)/10,0,math.random(-4,4)/10), ray.Normal, false, math.random(18,42)/100)
                            end
                            conn:Disconnect()
                            droplet:Destroy()
                            return
                        end
                    end
                end
                lastPos = cur
            end)
            task.delay(0.72, function() if conn then conn:Disconnect() end if droplet.Parent then droplet:Destroy() end end)
        end)
    end
end

local function addWound_Type1(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type1(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type2(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type2(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type3(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type3(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type4(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type4(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type5(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type5(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type6(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type6(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type7(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type7(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type8(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type8(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type9(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type9(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type10(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type10(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type11(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type11(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type12(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type12(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type13(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type13(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type14(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type14(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type15(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type15(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type16(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type16(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type17(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type17(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type18(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type18(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type19(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type19(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type20(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type20(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type21(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type21(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type22(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type22(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type23(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type23(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type24(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type24(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type25(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type25(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type26(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type26(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type27(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type27(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type28(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type28(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type29(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type29(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type30(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type30(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type31(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type31(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type32(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type32(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type33(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type33(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type34(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type34(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type35(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type35(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type36(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type36(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type37(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type37(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type38(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type38(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type39(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type39(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function addWound_Type40(char, critical)
    if not char then return end
    local parts = {"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
    local count = critical and 2 or 1
    for k=1,count do
        local pn = parts[math.random(1,#parts)]
        local part = char:FindFirstChild(pn) or char:FindFirstChild("UpperTorso")
        if part then
            for _,face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                if math.random() < 0.65 then
                    local d = Instance.new("Decal")
                    d.Name = "Wound"
                    d.Texture = CONFIG.BLOOD_TEXTURES[math.random(1,#CONFIG.BLOOD_TEXTURES)]
                    d.Face = face
                    d.Color3 = getBloodColor()
                    d.Transparency = 0
                    d.Parent = part
                end
            end
            if not woundCounts[char] then woundCounts[char] = 0 end
            woundCounts[char] = woundCounts[char] + 1
            task.spawn(function()
                for b=1,5 do
                    task.wait(0.48 + math.random(0,10)/100)
                    if not part.Parent then break end
                    createPhysicalBloodPart_Type40(part.Position - Vector3.new(0,0.32,0), char, 1, true)
                end
            end)
        end
    end
end

local function createSimpleRagdoll_Type1(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 1 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type2(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 2 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type3(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 3 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type4(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 4 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type5(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 5 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type6(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 6 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type7(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 7 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type8(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 8 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type9(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 9 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type10(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 10 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type11(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 11 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type12(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 12 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type13(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 13 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type14(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 14 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type15(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 15 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type16(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 16 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type17(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 17 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type18(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 18 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type19(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 19 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createSimpleRagdoll_Type20(character)
    if ragdolledChars[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    humanoid.BreakJointsOnDeath = true
    humanoid.RequiresNeck = false
    local motors = {}
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("Motor6D") then table.insert(motors, v) end end
    local constraints = {}
    for _,motor in ipairs(motors) do
        if motor.Part0 and motor.Part1 and motor.Name ~= "RootJoint" then
            local a0 = Instance.new("Attachment") a0.CFrame = motor.C0 a0.Parent = motor.Part0
            local a1 = Instance.new("Attachment") a1.CFrame = motor.C1 a1.Parent = motor.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Attachment0 = a0 socket.Attachment1 = a1 socket.LimitsEnabled = true socket.UpperAngle = 44 + 20 socket.TwistLimitsEnabled = true socket.TwistLowerAngle = -58 socket.TwistUpperAngle = 58 socket.Restitution = 0.14 socket.Parent = motor.Part0
            table.insert(constraints, {socket=socket, a0=a0, a1=a1, motor=motor})
            motor.Enabled = false
        end
    end
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    ragdolledChars[character] = {constraints=constraints, motors=motors, humanoid=humanoid}
    task.delay(6 + math.random(0,10)/10, function()
        local data = ragdolledChars[character]
        if data then
            for _,c in ipairs(data.constraints) do if c.socket then c.socket:Destroy() end if c.a0 then c.a0:Destroy() end if c.a1 then c.a1:Destroy() end if c.motor then c.motor.Enabled = true end end
            if data.humanoid then data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
            ragdolledChars[character] = nil
        end
    end)
end

local function createPartPuddle(pos, normal, isFoot, sizeOverride)
    local idx = math.random(1,80)
    if idx == 1 then return createPartPuddle_Type1(pos, normal, isFoot, sizeOverride)
    elseif idx == 2 then return createPartPuddle_Type2(pos, normal, isFoot, sizeOverride)
    elseif idx == 3 then return createPartPuddle_Type3(pos, normal, isFoot, sizeOverride)
    elseif idx == 4 then return createPartPuddle_Type4(pos, normal, isFoot, sizeOverride)
    elseif idx == 5 then return createPartPuddle_Type5(pos, normal, isFoot, sizeOverride)
    else return createPartPuddle_Type6(pos, normal, isFoot, sizeOverride) end
end

local function createPhysicalBloodPart(pos, char, count, small, velOverride)
    local idx = math.random(1,80)
    if idx <= 10 then return createPhysicalBloodPart_Type1(pos, char, count, small, velOverride)
    elseif idx <= 20 then return createPhysicalBloodPart_Type2(pos, char, count, small, velOverride)
    elseif idx <= 30 then return createPhysicalBloodPart_Type3(pos, char, count, small, velOverride)
    elseif idx <= 40 then return createPhysicalBloodPart_Type4(pos, char, count, small, velOverride)
    elseif idx <= 50 then return createPhysicalBloodPart_Type5(pos, char, count, small, velOverride)
    else return createPhysicalBloodPart_Type6(pos, char, count, small, velOverride) end
end

local function addWound(char, critical)
    local idx = math.random(1,40)
    if idx <= 10 then return addWound_Type1(char, critical)
    elseif idx <= 20 then return addWound_Type2(char, critical)
    elseif idx <= 30 then return addWound_Type3(char, critical)
    else return addWound_Type4(char, critical) end
end

local function createSimpleRagdoll(char)
    return createSimpleRagdoll_Type1(char)
end

-- UI CLEAR JELAS - NO GREEN BUG
local function createClearDisclaimerUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "FolkValleyDisclaimer"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = player:WaitForChild("PlayerGui")
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(0,0,0)
    bg.BackgroundTransparency = 0.06
    bg.BorderSizePixel = 0
    bg.Parent = sg
    local blur = Instance.new("BlurEffect")
    blur.Name = "DisclaimerBlur"
    blur.Size = 14
    blur.Parent = Lighting
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0,390,0,480)
    box.Position = UDim2.new(0.5,-195,0.5,-240)
    box.BackgroundColor3 = Color3.fromRGB(14,14,14)
    box.BorderSizePixel = 0
    box.ClipsDescendants = true
    box.Parent = bg
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,18)
    local stroke = Instance.new("UIStroke", box)
    stroke.Color = Color3.fromRGB(85,15,15)
    stroke.Thickness = 1.4
    stroke.Transparency = 0.15
    local bgImg = Instance.new("ImageLabel")
    bgImg.Size = UDim2.new(1,0,1,0)
    bgImg.BackgroundTransparency = 1
    bgImg.Image = CONFIG.DISCLAIMER_BG_ID
    bgImg.ImageTransparency = 0.70
    bgImg.ScaleType = Enum.ScaleType.Crop
    bgImg.Parent = box
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1,0,1,0)
    overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
    overlay.BackgroundTransparency = 0.20
    overlay.BorderSizePixel = 0
    overlay.Parent = box
    local grad = Instance.new("UIGradient", overlay)
    grad.Color = ColorSequence.new(Color3.fromRGB(8,8,8), Color3.fromRGB(35,0,0))
    grad.Rotation = 90
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1,0,1,0)
    content.BackgroundTransparency = 1
    content.Parent = box
    for i=1,7 do
        local drip = Instance.new("Frame")
        drip.Size = UDim2.new(0,3,0,math.random(14,28))
        drip.Position = UDim2.new(0, 16 + i*50 + math.random(-4,4), 0, 0)
        drip.BackgroundColor3 = Color3.fromRGB(180,0,0)
        drip.BorderSizePixel = 0
        drip.Parent = content
        Instance.new("UICorner", drip).CornerRadius = UDim.new(1,0)
    end
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,-28,0,30)
    title.Position = UDim2.new(0,14,0,20)
    title.BackgroundTransparency = 1
    title.Text = "FOLK VALLEY"
    title.TextColor3 = Color3.new(1,1,1)
    title.TextSize = 26
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = content
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1,-28,0,14)
    subtitle.Position = UDim2.new(0,14,0,52)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "PHYSICAL PART BLOOD • RAGDOLL • OVERGROWTH BLEEDING"
    subtitle.TextColor3 = Color3.fromRGB(210,45,45)
    subtitle.TextSize = 9
    subtitle.Font = Enum.Font.GothamBold
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = content
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1,-28,0,140)
    desc.Position = UDim2.new(0,14,0,72)
    desc.BackgroundTransparency = 1
    desc.Text = "FIXED BUGS:\n• Blood now sticks to WALLS & GROUND (raycast any surface)\n• No blood when just walking - only when wounded\n• Green blood bug fixed - only red unless checkbox\n• Part puddles like video @sizi0 - block parts not decals\n• Physical ball droplets with trail\n• No TP - no WeldConstraint\n• Drip + alarm sounds"
    desc.TextColor3 = Color3.fromRGB(225,225,225)
    desc.TextSize = 11
    desc.TextWrapped = true
    desc.Font = Enum.Font.Gotham
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.Parent = content
    local warnBox = Instance.new("Frame")
    warnBox.Size = UDim2.new(1,-28,0,38)
    warnBox.Position = UDim2.new(0,14,0,220)
    warnBox.BackgroundColor3 = Color3.fromRGB(65,12,12)
    warnBox.BackgroundTransparency = 0.4
    warnBox.BorderSizePixel = 0
    warnBox.Parent = content
    Instance.new("UICorner", warnBox).CornerRadius = UDim.new(0,8)
    local warnText = Instance.new("TextLabel")
    warnText.Size = UDim2.new(1,-12,1,-8)
    warnText.Position = UDim2.new(0,6,0,4)
    warnText.BackgroundTransparency = 1
    warnText.Text = "⚠ Realistic blood, ragdoll, beating heart. Slow 3s when hit. Blood sticks to walls."
    warnText.TextColor3 = Color3.fromRGB(255,130,130)
    warnText.TextSize = 9
    warnText.TextWrapped = true
    warnText.Font = Enum.Font.GothamMedium
    warnText.TextXAlignment = Enum.TextXAlignment.Left
    warnText.Parent = warnBox
    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1,-28,0,46)
    input.Position = UDim2.new(0,14,0,270)
    input.BackgroundColor3 = Color3.fromRGB(28,28,28)
    input.Text = ""
    input.PlaceholderText = "Type BLOOD to continue"
    input.TextColor3 = Color3.new(1,1,1)
    input.PlaceholderColor3 = Color3.fromRGB(115,115,115)
    input.TextSize = 13
    input.Font = Enum.Font.GothamMedium
    input.Parent = content
    Instance.new("UICorner", input).CornerRadius = UDim.new(0,10)
    local inputStroke = Instance.new("UIStroke", input)
    inputStroke.Color = Color3.fromRGB(60,60,60)
    inputStroke.Thickness = 1
    local btnFrame = Instance.new("Frame")
    btnFrame.Size = UDim2.new(1,-28,0,50)
    btnFrame.Position = UDim2.new(0,14,0,330)
    btnFrame.BackgroundColor3 = Color3.fromRGB(38,38,38)
    btnFrame.BorderSizePixel = 0
    btnFrame.Parent = content
    Instance.new("UICorner", btnFrame).CornerRadius = UDim.new(0,10)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0,0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(180,0,0)
    fill.BorderSizePixel = 0
    fill.Parent = btnFrame
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0,10)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = "ENTER VALLEY"
    btn.TextColor3 = Color3.fromRGB(145,145,145)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.Parent = btnFrame
    input:GetPropertyChangedSignal("Text"):Connect(function()
        if input.Text:upper() == "BLOOD" then
            TweenService:Create(fill, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1,0,1,0)}):Play()
            TweenService:Create(inputStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(180,0,0)}):Play()
            btn.TextColor3 = Color3.new(1,1,1)
        else
            TweenService:Create(fill, TweenInfo.new(0.22), {Size = UDim2.new(0,0,1,0)}):Play()
            TweenService:Create(inputStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(60,60,60)}):Play()
            btn.TextColor3 = Color3.fromRGB(145,145,145)
        end
    end)
    btn.MouseButton1Click:Connect(function()
        if input.Text:upper() ~= "BLOOD" then
            local orig = box.Position
            for i=1,3 do TweenService:Create(box, TweenInfo.new(0.06), {Position = orig + UDim2.new(0,6,0,0)}):Play() task.wait(0.06) TweenService:Create(box, TweenInfo.new(0.06), {Position = orig - UDim2.new(0,6,0,0)}):Play() task.wait(0.06) end
            TweenService:Create(box, TweenInfo.new(0.1), {Position = orig}):Play()
            return
        end
        local blurObj = Lighting:FindFirstChild("DisclaimerBlur")
        if blurObj then blurObj:Destroy() end
        TweenService:Create(bg, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
        TweenService:Create(box, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0), Position = UDim2.new(0.5,0,0.5,0)}):Play()
        task.wait(0.35)
        bg:Destroy()
        canGore = true
    end)
end

local function createBloodSplatter(pos, count)
    count = count or math.random(10,18)
    for i=1,count do
        task.delay((i-1)*0.018, function()
            local offset = Vector3.new(math.random(-14,14)/10, 0, math.random(-14,14)/10)
            local ground = getGround(pos + offset)
            if ground then createPartPuddle(ground.Position, ground.Normal, false, math.random(28,92)/100) end
            local wall = getAnySurface(pos + offset + Vector3.new(0,1,0), Vector3.new(math.random(-10,10)/10, math.random(-5,5)/10, math.random(-10,10)/10).Unit * 4)
            if wall and wall.Normal.Y < 0.5 then createPartPuddle(wall.Position, wall.Normal, false, math.random(20,50)/100) end
        end)
    end
end

local function loadHeart(pos)
    local ok,obj = pcall(function() return game:GetObjects("rbxassetid://"..CONFIG.HEART_ID)[1] end)
    if not ok or not obj then return end
    local model = obj:IsA("Model") and obj or obj:FindFirstChildOfClass("Model") or obj
    if not model:IsA("Model") then local w = Instance.new("Model") obj.Parent = w model = w end
    for _,v in ipairs(model:GetDescendants()) do if v:IsA("Script") or v:IsA("LocalScript") then v:Destroy() end end
    model.Parent = organs
    model:PivotTo(CFrame.new(pos + Vector3.new(0,1.3,0)))
    local prim = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if prim then
        prim.Anchored = false prim.CanCollide = true
        task.spawn(function()
            for i=1,12 do
                if not model.Parent then break end
                pcall(function() model:ScaleTo(model:GetScale()*1.13) end)
                playSound(CONFIG.KREK_ID1, prim, 0.75, 0.82)
                createPhysicalBloodPart(prim.Position, nil, 2, true)
                local g = getGround(prim.Position)
                if g then createPartPuddle(g.Position, g.Normal, false, 0.32) end
                task.wait(0.11)
                pcall(function() model:ScaleTo(model:GetScale()/1.13) end)
                task.wait(0.44)
            end
        end)
        task.spawn(function()
            while model.Parent do
                task.wait(0.18)
                for _,plr in ipairs(Players:GetPlayers()) do
                    if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = plr.Character.HumanoidRootPart
                        if (hrp.Position - prim.Position).Magnitude < 2.9 then
                            createBloodSplatter(prim.Position, 14)
                            createPhysicalBloodPart(prim.Position, nil, 9, false)
                            playSound(CONFIG.KREK_ID2, prim, 1.25)
                            model:Destroy()
                            break
                        end
                    end
                end
            end
        end)
    end
    task.delay(13, function() if model.Parent then model:Destroy() end end)
end

createClearDisclaimerUI()

local function setupCharacter(char)
    local humanoid = char:WaitForChild("Humanoid")
    local root = char:WaitForChild("HumanoidRootPart")
    resetFX()
    for _,v in ipairs(char:GetDescendants()) do if v:IsA("Decal") and v.Name=="Wound" then v:Destroy() end end
    local defaultSpeed = CONFIG.NORMAL_WALKSPEED
    humanoid.WalkSpeed = defaultSpeed
    local slowed = false
    local lastHealth = humanoid.Health
    bloodLeft = 1.0 footCount = 0 lastFootPos = nil
    woundCounts[char] = 0
    local bleedingConn
    bleedingConn = RunService.Heartbeat:Connect(function()
        if not char.Parent or humanoid.Health <= 0 then bleedingConn:Disconnect() return end
        if woundCounts[char] and woundCounts[char] > 0 and bloodLeft < 0.95 then
            if math.random() < 0.06 then
                local g = getGround(root.Position)
                if g then createPartPuddle(g.Position, g.Normal, false, 0.22) end
            end
        end
    end)
    humanoid.HealthChanged:Connect(function(n)
        if n < lastHealth and n > 0 and not slowed then
            slowed = true
            addWound(char, lastHealth - n >= 10)
            playSound(CONFIG.KREK_ID1, root, 1.05)
            task.wait(0.09)
            playSound(CONFIG.KREK_ID2, root, 1.05)
            humanoid.WalkSpeed = CONFIG.SLOW_WALKSPEED
            bImg.Visible = true bImg.ImageTransparency = 0.36
            TweenService:Create(bImg, TweenInfo.new(2.3), {ImageTransparency = 1}):Play()
            task.delay(2.35, function() bImg.Visible=false end)
            createPhysicalBloodPart(root.Position, char, 7, false)
            local g = getGround(root.Position)
            if g then createPartPuddle(g.Position, g.Normal, false) createBloodSplatter(g.Position, 6) end
            local w = getAnySurface(root.Position, Vector3.new(math.random(-10,10)/10, 0, math.random(-10,10)/10).Unit * 3)
            if w then createPartPuddle(w.Position, w.Normal, false) end
            if lastHealth - n >= 18 then createSimpleRagdoll(char) end
            task.delay(CONFIG.SLOW_DURATION, function() humanoid.WalkSpeed = defaultSpeed slowed = false end)
        elseif n < lastHealth and n > 0 then
            createPhysicalBloodPart(root.Position, char, 3, true)
            addWound(char, false)
        end
        lastHealth = n
    end)
    humanoid.Died:Connect(function()
        if not canGore then return end
        playSound(CONFIG.DEATH_ID, player.PlayerGui, 2.1)
        playSound(CONFIG.ALARM_ID, player.PlayerGui, 2.6)
        local cc = Instance.new("ColorCorrectionEffect") cc.Name = "DeathInvert" cc.TintColor = Color3.fromRGB(255,205,205) cc.Saturation = -0.22 cc.Parent = Lighting
        local bl = Instance.new("BlurEffect") bl.Name = "DeathBlur" bl.Size = 2 bl.Parent = Lighting
        bImg.Visible = true bImg.ImageTransparency = 0.23 task.delay(3.6, function() resetFX() end)
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        if torso then loadHeart(torso.Position) createPhysicalBloodPart(torso.Position, char, 8, false) createBloodSplatter(torso.Position, 12) createSimpleRagdoll(char) end
        for i=1,5 do task.delay(i*0.11, function() addWound(char, true) end) end
    end)
    local footUntil = 0 local lastStep = 0 local side = false local conn
    conn = RunService.Heartbeat:Connect(function()
        if not char.Parent then conn:Disconnect() return end
        if tick()-lastStep < 0.35 then return end
        if humanoid.MoveDirection.Magnitude < 0.25 then return end
        if woundCounts[char] == nil or woundCounts[char] == 0 then return end
        local fp = RaycastParams.new() fp.FilterDescendantsInstances = {bloods, organs, char} fp.FilterType = Enum.RaycastFilterType.Exclude
        local check = workspace:Raycast(root.Position + Vector3.new(0,1,0), Vector3.new(0,-4,0), fp)
        if check and check.Instance.Parent == puddles and check.Instance:GetAttribute("IsFootprint") == nil then if check.Instance.Size.X >= 0.55 then footUntil = tick()+4 bloodLeft=1.0 footCount=0 end end
        if tick() > footUntil then return end
        lastStep = tick() side = not side
        local foot = char:FindFirstChild(side and "RightFoot" or "LeftFoot") or root
        local ray = workspace:Raycast(foot.Position + Vector3.new(0,1,0), Vector3.new(0,-3,0), fp)
        if ray then
            local ground = getGround(ray.Position)
            if ground then
                if lastFootPos and (ground.Position - lastFootPos).Magnitude < 5 then
                    local dir = (ground.Position - lastFootPos) local steps = math.floor(dir.Magnitude/0.5)
                    for i=1,steps-1 do local lp = lastFootPos + dir.Unit*(i*0.5) local rr = workspace:Raycast(lp + Vector3.new(0,1,0), Vector3.new(0,-3,0), fp) if rr then local gg = getGround(rr.Position) if gg then createPartPuddle(gg.Position, gg.Normal, true) end end end
                end
                createPartPuddle(ground.Position, ground.Normal, true)
                lastFootPos = ground.Position
            end
        end
    end)
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

local function optimizeBlood()
    while true do task.wait(8)
        if #puddles:GetChildren() > CONFIG.MAX_PUDDLES * 0.85 then for i=1,12 do if puddles:GetChildren()[1] then puddles:GetChildren()[1]:Destroy() end end end
        if #bloods:GetChildren() > CONFIG.MAX_BLOOD_PARTS * 0.9 then for i=1,6 do if bloods:GetChildren()[1] then bloods:GetChildren()[1]:Destroy() end end end
    end
end
task.spawn(optimizeBlood)

print("FOLK VALLEY 10K PURE CODE LOADED - PART BLOOD FIXED - NO GREEN BUG - STICKS TO WALL & GROUND")