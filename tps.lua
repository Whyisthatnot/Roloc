setfpscap(5)
_G.AutoTap = true
_G.AutoRebirthMax = true
_G.AutoCollectQuest = true
_G.AutoBuyWorld = true
_G.AutoUpgrade = true
_G.AutoClaimRank = true 
_G.AutoElectricSpin = true
_G.AutoBuyPotion = true
_G.AutoPotion = {
    ["Enabled"] = true,
    ["Use"] = {
        "Luck",
        "Taco",
        "Octo"
    }
}
_G.AutoHatch = {
    ["Enabled"] = true,
    ["Egg"] = {
        ["Lightning Event"] = true,
    }
}
_G.AutoGoldenConfig = {
    ["Enabled"] = true,
    ["Pets"] = {
        ["Electrical Glitch"] = 4,
    }
}
_G.AutoRainbow = {
    ["Enabled"] = true,
    ["Pets"] = {
        ["Electrical Glitch"] = 5,
    }
}

-- [[ SERVICES & MODULES ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Network = require(ReplicatedStorage.Modules.Network)
local Replication = require(ReplicatedStorage.Game.Replication)
local Rebirths = require(ReplicatedStorage.Game.Rebirths)
local Quests = require(ReplicatedStorage.Game.Quests)
local Worlds = require(ReplicatedStorage.Game.Worlds)
local Player = game.Players.LocalPlayer
local Network = require(game:GetService("ReplicatedStorage").Modules.Network)
local GemShopData = require(game:GetService("ReplicatedStorage").Game.GemShop)
local Replication = require(game:GetService("ReplicatedStorage").Game.Replication)
local EggDatabase = require(ReplicatedStorage.Game.Eggs)

--- --- --- --- --- --- --- --- --- --- --- --- ---
-- [[ LUỒNG 1: AUTO TAP (HEARTBEAT) ]]
--- --- --- --- --- --- --- --- --- --- --- --- ---

_G.TapsPerSecond = 555
_G.IsRebirthing = false -- Cầu chì ngắt các luồng khác khi đang Rebirth
local RunService = game:GetService("RunService")
local tapAcc = 0

RunService.Heartbeat:Connect(function(dt)
    if _G.AutoTap and not _G.IsRebirthing then
        tapAcc = tapAcc + dt
        local tapInterval = 1 / (_G.TapsPerSecond or 10)
        local taps = math.floor(tapAcc / tapInterval)

        if taps > 0 then
            for i = 1, math.min(taps, 50) do 
                if _G.IsRebirthing then break end
                Network:FireServer("Tap", true, false, true)
            end
            tapAcc = 0
        end
    else
        tapAcc = 0 
    end
end)
local function SmartCleanInventory()
    local Network = require(game:GetService("ReplicatedStorage").Modules.Network)
    local Replication = require(game:GetService("ReplicatedStorage").Game.Replication)
    local PetStats = require(game:GetService("ReplicatedStorage").Game.Eggs) -- Dùng database trứng/pet

    local inventory = Replication.Data.Pets
    if not inventory then return end

    local RarityPriority = {
        ["Mythical"] = 5, ["Legendary"] = 4, ["Epic"] = 3, 
        ["Rare"] = 2, ["Uncommon"] = 1, ["Common"] = 0
    }

    local TierPriority = {
        ["Void"] = 4, ["Rainbow"] = 3, ["Golden"] = 2, ["Normal"] = 1
    }

    local SafeRarities = {
        ["Secret I"] = true, ["Secret II"] = true, ["Secret III"] = true, 
        ["Godly"] = true, ["Divine"] = true, ["Celestial"] = true, ["Exotic"] = true
    }
    
    local allPets = {}
    
    for id, data in pairs(inventory) do
        -- Lấy rarity từ database nếu data.Rarity không có sẵn
        local rarity = data.Rarity or "Common"
        local tier = data.Tier or "Normal"
        
        if data.Equipped or data.Locked or SafeRarities[rarity] then
            continue 
        end

        table.insert(allPets, {
            id = id,
            rarityLevel = RarityPriority[rarity] or 0,
            tierLevel = TierPriority[tier] or 0
        })
    end

    -- Sắp xếp: Con mạnh lên đầu
    table.sort(allPets, function(a, b) 
        if a.rarityLevel ~= b.rarityLevel then
            return a.rarityLevel > b.rarityLevel
        end
        return a.tierLevel > b.tierLevel 
    end)

    -- Gom ID cần xóa
    local idsToDelete = {}
    local MAX_KEEP = 30 -- Chỉ giữ 30 con mạnh nhất

    for i, pet in ipairs(allPets) do
        if i > MAX_KEEP then
            table.insert(idsToDelete, pet.id)
        end
    end

    -- THỰC THI XÓA HÀNG LOẠT (BULK DELETE)
    if #idsToDelete > 0 then
        
        -- Thử nghiệm gửi cả bảng ID (Cách nhanh nhất)
        local success = Network:InvokeServer("DeletePet", idsToDelete)
        
        -- Nếu Server không hỗ trợ gửi cả bảng (vẫn in báo lỗi), 
        -- nó sẽ tự động dùng vòng lặp siêu tốc không wait
        if not success then
             for _, petId in pairs(idsToDelete) do
                task.spawn(function() 
                    Network:InvokeServer("DeletePet", petId) 
                end)
             end
        end
    end
end

-- Vòng lặp chạy mỗi 10 giây (nhanh hơn để tránh full kho)
task.spawn(function()
    while true do
        pcall(function()
            local Network = require(game:GetService("ReplicatedStorage").Modules.Network)
            Network:InvokeServer("EquipBest")
            task.wait(0.5)
            SmartCleanInventory()
        end)
        task.wait()
    end
end)
-- [[ CONFIG CỐ ĐỊNH ]]
local MoneyNeeded = 1000000000000 -- 1 Trillion

-- [[ 1. HOOK BYPASS BYPASS DELAY SERVER ]]
local oldInvoke = Network.InvokeServer
Network.InvokeServer = function(self, method, ...)
    local args = {...}
    if method == "OpenEgg" then
        task.spawn(function()
            pcall(function()
                return oldInvoke(self, method, unpack(args))
            end)
        end)
        return true 
    end
    return oldInvoke(self, method, ...)
end

-- [[ 2. HÀM TỰ ĐỘNG CHỌN TRỨNG THÔNG MINH ]]
local function GetTargetEgg()
    local data = Replication.Data
    if not data or not data.Statistics then return nil end
    local currentClicks = data.Statistics.Clicks or 0

    if currentClicks >= MoneyNeeded then
        for targetName, isEnabled in pairs(_G.AutoHatch["Egg"]) do
            if isEnabled and EggDatabase[targetName] then return targetName end
        end
        for eggName, _ in pairs(EggDatabase) do
            if string.find(string.lower(eggName), "lightning") then return eggName end
        end
    end

    local bestEgg, maxPrice = nil, -1
    for eggName, eggData in pairs(EggDatabase) do
        if type(eggData) == "table" and eggData.Price and (eggData.Currency or "Clicks") == "Clicks" then
            if eggData.Price <= currentClicks and eggData.Price > maxPrice then
                maxPrice, bestEgg = eggData.Price, eggName
            end
        end
    end
    return bestEgg
end

-- [[ 3. VÒNG LẶP CHÍNH ]]
print("🚀 AUTO EGG STARTED - BYPASS ENABLED")

task.spawn(function()
    while _G.AutoHatch["Enabled"] do
        local data = Replication.Data
        if data and data.Statistics then
            local target = GetTargetEgg()
            local currentClicks = data.Statistics.Clicks or 0
            
            if target then
                local hatchAmount = 1
                if currentClicks >= MoneyNeeded then
                    if (data.Gamepasses and data.Gamepasses["x8Egg"]) or 
                       (data.ActiveBoosts and data.ActiveBoosts["Octo Incubator"] and data.ActiveBoosts["Octo Incubator"] > 0) then
                        hatchAmount = 8
                    else
                        hatchAmount = 3
                    end
                end
                -- Gửi lệnh mở trứng
                Network:InvokeServer("OpenEgg", target, hatchAmount, {})
            end
        end
        task.wait(0.01) -- Tốc độ spam tối đa
    end
end)


--- --- --- --- --- --- --- --- --- --- --- --- ---
-- [[ LUỒNG 3: LOGIC REBIRTH, WORLD & QUEST ]]
--- --- --- --- --- --- --- --- --- --- --- --- ---
task.spawn(function()
    local lastRebirthTick = 0
    while task.wait(0.2) do
        local data = Replication.Data
        if not data or not data.Statistics then continue end

        -- 1. Auto Rebirth Max (Giới hạn Index tối đa là 20)
        if _G.AutoRebirthMax == true and not _G.IsRebirthing then
            local options = data.RebirthOptions
            -- Lấy index cao nhất hiện có trong data
            local rawMaxIdx = (type(options) == "table" and #options) or (tonumber(options) or 0)
            
            -- CHỈNH SỬA TẠI ĐÂY: Dùng math.min để giới hạn tối đa là 20
            local maxIdx = math.min(rawMaxIdx, 23) 

            if maxIdx > 0 and (tick() - lastRebirthTick >= 0.5) then
                local rbAmount = Rebirths:fromIndex(maxIdx)
                local basePrice = Rebirths:getPrice(rbAmount)
                local finalPrice = Rebirths:ClicksPrice(basePrice, data.Statistics.Rebirths)

                if data.Statistics.Clicks >= finalPrice then
                    _G.IsRebirthing = true 
                    task.wait(0.1)
                    
                    local success = pcall(function()
                        -- Thực hiện rebirth với index đã giới hạn
                        return Network:InvokeServer("Rebirth", maxIdx)
                    end)
                    
                    if success then
                        lastRebirthTick = tick()
                    end
                    
                    task.wait(0.2)
                    _G.IsRebirthing = false 
                end
            end
        end

        -- 3. Auto Claim Quest
        if _G.AutoCollectQuest == true and data.Quests then
            for qName, qData in pairs(data.Quests) do
                if not qData.Claimed and qData.Amount >= (Quests[qName] and Quests[qName].Goal or 9e9) then
                    pcall(function() Network:InvokeServer("ClaimQuest", qName) end)
                end
            end
        end
    end
end)

--- --- --- --- --- --- --- --- --- --- --- --- ---
-- [[ LUỒNG 4: AUTO ZONE (PORTAL) ]]
--- --- --- --- --- --- --- --- --- --- --- --- ---
local function AutoOpenBestPortal()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Network = require(ReplicatedStorage.Modules.Network)
    local Replication = require(ReplicatedStorage.Game.Replication)
    local PortalsData = require(ReplicatedStorage.Game.Portals)
    
    -- 1. Lấy danh sách cổng và sắp xếp theo giá (y hệt logic của game)
    local sortedPortals = {}
    for name, data in pairs(PortalsData) do
        table.insert(sortedPortals, {Name = name, Price = data.Price})
    end
    
    table.sort(sortedPortals, function(a, b)
        return a.Price < b.Price
    end)

    -- 2. Kiểm tra dữ liệu người chơi
    if not Replication.Loaded or not Replication.Data then return end
    
    local currentClicks = Replication.Data.Statistics.Clicks
    local ownedPortals = Replication.Data.Portals

    -- 3. Tìm cổng tiếp theo chưa sở hữu mà bạn đủ tiền mua
    for _, portal in ipairs(sortedPortals) do
        if not ownedPortals[portal.Name] then
            if currentClicks >= portal.Price then
                print("--- Đang tự động mở cổng: " .. portal.Name .. " (" .. portal.Price .. " Clicks) ---")
                
                -- Gọi Remote mua cổng từ server
                local success = Network:InvokeServer("BuyPortal", portal.Name)
                
                if success then
                    print("✅ Đã mở khóa thành công portal: " .. portal.Name)
                else
                    print("❌ Không thể mua " .. portal.Name .. ". Có thể do chưa mở cổng trước đó.")
                end
                -- Sau khi thử mua 1 cổng thì dừng lại để chờ chu kỳ sau
                return 
            else
                -- Nếu không đủ tiền mua cổng này, thì chắc chắn không đủ tiền mua các cổng sau (vì đã sắp xếp theo giá)
                break
            end
        end
    end
end

task.spawn(function()
    while _G.AutoBuyWorld == true do
        pcall(AutoOpenBestPortal)
        task.wait()
    end
end)

local function autoBuyUpgrades()
    for upgradeName, details in pairs(GemShopData) do
        -- Get current level from the replication module
        local currentLevel = Replication.Data.GemShop[upgradeName] or 0
        local maxLevel = details.Total
        
        -- If not maxed, try to upgrade
        if currentLevel < maxLevel then
            -- Invoke the server (Matching the decompiled signature)
            Network:InvokeServer("UpgradeGemShop", upgradeName, nil)
            task.wait(0.1) -- Small delay to prevent crashing/kicking
        end
    end
end
task.spawn(function()
    while _G.AutoUpgrade == true do
        autoBuyUpgrades()
        Network:InvokeServer("UpgradeGemShop", "RebirthButtons")
        task.wait(1)
    end
end)



task.spawn(function()
    while _G.AutoClaimRank == true do
        -- Kiểm tra dữ liệu game đã tải xong chưa
        local data = Replication.Data
        if data and data.Ranks then
            local currentTime = os.time()
            local nextRewardTime = data.Ranks.NextRewardTime or 0
            
            -- Nếu thời gian hiện tại đã vượt qua thời gian chờ nhận thưởng
            if currentTime >= nextRewardTime then
                
                -- Gọi Remote nhận thưởng giống như khi bấm nút
                local success, response = Network:InvokeServer("ClaimRankReward")
                
                if success then
                    print("✅ Nhận thưởng thành công!")
                    -- Chờ thêm một chút để dữ liệu Server cập nhật
                    task.wait(2) 
                end
            end
        end
        
        -- Kiểm tra mỗi 5 giây để tránh làm lag máy
        task.wait(5)
    end
end)


-- Tọa độ máy Golden mặc định ông vừa đưa
local GOLDEN_MACHINE_POS = Vector3.new(-192.82, 221.40, 197.21)

local function RunAutoCraftGolden()
    local Config = _G.AutoGoldenConfig
    if not Config or not Config.Enabled then return end

    local Replication = require(game:GetService("ReplicatedStorage").Game.Replication)
    local Network = require(game:GetService("ReplicatedStorage").Modules.Network)
    local Player = game.Players.LocalPlayer
    local Character = Player.Character
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    
    local RootPart = Character.HumanoidRootPart
    if not Replication.Data or not Replication.Data.Pets then return end
    
    local inventory = Replication.Data.Pets
    local groups = {}
    local oldCFrame = RootPart.CFrame -- Lưu vị trí đang đứng farm
    local needsToTeleport = false

    -- 1. Quét túi đồ và kiểm tra điều kiện
    for id, petData in pairs(inventory) do
        if petData.Tier == "Normal" and not petData.Locked and not petData.Equipped then
            local pNameLower = string.lower(petData.Name)
            for targetName, amount in pairs(Config.Pets) do
                if string.find(pNameLower, string.lower(targetName)) then
                    if not groups[petData.Name] then
                        groups[petData.Name] = { ids = {}, required = amount }
                    end
                    table.insert(groups[petData.Name].ids, id)
                    break 
                end
            end
        end
    end

    -- 2. Kiểm tra xem có đủ pet để thực hiện ít nhất 1 lần ép không
    for _, data in pairs(groups) do
        if #data.ids >= data.required then
            needsToTeleport = true
            break
        end
    end

    -- 3. Thực hiện Teleport và Ép
    if needsToTeleport then
        RootPart.CFrame = CFrame.new(GOLDEN_MACHINE_POS)
        task.wait(0.6) -- Đợi server nhận vị trí

        for petRealName, data in pairs(groups) do
            local totalAvailable = #data.ids
            local amountPerCraft = data.required

            if totalAvailable >= amountPerCraft then
                local craftsPossible = math.floor(totalAvailable / amountPerCraft)
                
                for i = 1, craftsPossible do
                    local craftBatch = {}
                    for j = 1, amountPerCraft do
                        table.insert(craftBatch, table.remove(data.ids))
                    end
                    
                    local success = Network:InvokeServer("CraftPets", craftBatch)
                    if success then
                        print("✅ Golden thành công: " .. petRealName)
                    end
                    task.wait(0.5)
                end
            end
        end

        RootPart.CFrame = oldCFrame
    end
end

-- Vòng lặp kiểm tra mỗi 10 giây
task.spawn(function()
    while true do
        if _G.AutoGoldenConfig and _G.AutoGoldenConfig.Enabled then
            pcall(RunAutoCraftGolden)
        end
        task.wait(1)
    end
end)


local RAINBOW_MACHINE_POS = Vector3.new(1205.83, 668.98, -13383.21)

local function RunAutoRainbow()
    local Config = _G.AutoRainbow
    local Network = require(game:GetService("ReplicatedStorage").Modules.Network)
    local Replication = require(game:GetService("ReplicatedStorage").Game.Replication)
    local Player = game.Players.LocalPlayer
    local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    
    if not RootPart or not Replication.Data or not Replication.Data.Pets then return end

    local activeCrafts = Replication.Data.CraftingPets.Rainbow
    local oldCFrame = RootPart.CFrame
    local hasAction = false

    local needClaim = false
    for slotId, data in pairs(activeCrafts) do
        if data.EndTime - workspace:GetServerTimeNow() <= 0 then
            needClaim = true
            break
        end
    end

    local inventory = Replication.Data.Pets
    local batch = {}
    local canCraft = false
    for targetName, reqAmount in pairs(Config.Pets) do
        local tempBatch = {}
        for id, data in pairs(inventory) do
            if data.Tier == "Golden" and not data.Locked and not data.Equipped and string.find(data.Name, targetName) then
                table.insert(tempBatch, id)
            end
            if #tempBatch >= reqAmount then break end
        end
        if #tempBatch >= reqAmount then
            batch = tempBatch
            canCraft = true
            break
        end
    end

    local slotCount = 0
    for _ in pairs(activeCrafts) do slotCount = slotCount + 1 end

    if needClaim or (canCraft and slotCount < 3) then
        RootPart.CFrame = CFrame.new(RAINBOW_MACHINE_POS)
        task.wait()

        for slotId, data in pairs(activeCrafts) do
            if data.EndTime - workspace:GetServerTimeNow() <= 0 then
                Network:InvokeServer("ClaimRainbow", slotId)
                hasAction = true
                task.wait(0.5)
            end
        end

        if canCraft and slotCount < 3 then
            local success = Network:InvokeServer("StartRainbow", batch)
            if success then
                hasAction = true
            else
                Network:InvokeServer("StartRainbow", "1", batch)
            end
        end

        if hasAction then
            task.wait(0.5)
            RootPart.CFrame = oldCFrame
        end
    end
end

task.spawn(function()
    while true do
        if _G.AutoRainbow and _G.AutoRainbow.Enabled then
            pcall(RunAutoRainbow)
        end
        task.wait(1)
    end
end)
-- 1. Ẩn mọi thứ trong Workspace (Transparency = 1 và tắt Va chạm)
for _, item in ipairs(workspace:GetDescendants()) do
    if item:IsA("BasePart") and not item:IsDescendantOf(game.Players) then
        item.Transparency = 1
    end
end


task.spawn(function()
    while _G.AutoElectricSpin do
        -- Lấy dữ liệu lượt quay từ Replication module
        local data = Replication.Data
        local spins = data and data.Items and data.Items.ElectricSpins or 0
        
        -- Chỉ quay nếu có lượt (> 0) và không đang trong quá trình quay (_G.Spinning)
        if spins > 0 and not _G.Spinning then
            -- Gọi server để quay
            Network:InvokeServer("SpinWheel", "ElectricSpinWheel")
            print("Spun Wheel! Remaining: " .. (spins - 1))
            
            -- Đợi vòng quay kết thúc (khoảng 7 giây)
            task.wait(7)
        end
        
        task.wait(2) -- Kiểm tra lại sau mỗi 2 giây
    end
end)

task.spawn(function()
    
    while _G.AutoBuyPotion == true do
        local data = Replication.Data
        if data and data.PotionMachine then
            local currentTime = os.time()
            
            -- Ưu tiên mua gói 10 trước, rồi đến 3, rồi đến 1
            -- Logic này dựa trên cooldown10, cooldown3, cooldown1 trong code bạn đưa
            
            if data.PotionMachine.Cooldown10 - currentTime <= 0 then
                print("Đang mua x10 Potions...")
                local result = Network:InvokeServer("BuyPotionMachine", 10)
                task.wait(1) -- Đợi server xử lý
            
            elseif data.PotionMachine.Cooldown3 - currentTime <= 0 then
                print("Đang mua x3 Potions...")
                local result = Network:InvokeServer("BuyPotionMachine", 3)
                task.wait(1)
                
            elseif data.PotionMachine.Cooldown1 - currentTime <= 0 then
                print("Đang mua x1 Potion...")
                local result = Network:InvokeServer("BuyPotionMachine", 1)
                task.wait(1)
            end
        end
        task.wait(5) -- Kiểm tra lại mỗi 5 giây để tránh spam
    end
    
    print("--- Đã dừng Auto Potion ---")
end)
local function RunAutoPotion()
    -- Lấy dữ liệu túi đồ thực tế từ server
    local data = Replication.Data
    local realInventory = data and data.Boosts
    
    if not realInventory then return end

    -- Duyệt trực tiếp qua túi đồ thật
    for id, count in pairs(realInventory) do
        -- Nếu còn Potion trong túi
        if count > 0 then
            -- So sánh với danh sách keyword bạn muốn dùng trong _G.AutoPotion["Use"]
            for _, keyword in pairs(_G.AutoPotion["Use"]) do
                if string.find(string.lower(id), string.lower(keyword)) then
                    
                    -- Thực thi dùng Potion
                    task.spawn(function()
                        local success = Network:InvokeServer("UseBoost", id)
                        if success then
                            -- print("⭐ Đã sử dụng: " .. id)
                        end
                    end)
                    
                    -- Đợi một chút để tránh gửi quá nhiều yêu cầu cùng lúc (tránh lag/kick)
                    task.wait(0.2)
                end
            end
        end
    end
end

-- Luồng chạy Auto Potion
task.spawn(function()
    while true do
        if _G.AutoPotion and _G.AutoPotion["Enabled"] then
            pcall(RunAutoPotion)
        end
        -- Kiểm tra lại sau mỗi 2-5 giây là hợp lý nhất để tránh tốn tài nguyên
        task.wait() 
    end
end)
--------------------------
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local CoreGui = game:GetService('CoreGui')
local LocalPlayer = Players.LocalPlayer
---------------------------------------------------------
-- [[ PHẦN FIX GUI & LOGIC TÍNH TOÁN CHUẨN (+232) ]]
---------------------------------------------------------

local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'FullOverlayStats'
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 2147483647 
ScreenGui.IgnoreGuiInset = true 
ScreenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local Background = Instance.new('Frame', ScreenGui)
Background.Size = UDim2.new(1, 0, 1, 0) 
Background.BackgroundColor3 = Color3.new(0, 0, 0) 
Background.BackgroundTransparency = 0.5
Background.BorderSizePixel = 0

local MainFrame = Instance.new('Frame', Background)
MainFrame.Size = UDim2.new(0.9, 0, 0.9, 0)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundTransparency = 1

local Layout = Instance.new('UIListLayout', MainFrame)
Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Layout.VerticalAlignment = Enum.VerticalAlignment.Center
Layout.Padding = UDim.new(0.012, 0)

local function createLabel(name, text, color, order)
    local label = Instance.new('TextLabel', MainFrame)
    label.Name = name
    label.Text = text
    label.TextColor3 = color
    label.Font = Enum.Font.LuckiestGuy
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0.9, 0, 0.08, 0)
    label.TextScaled = true 
    label.LayoutOrder = order
    local UIStroke = Instance.new('UIStroke', label)
    UIStroke.Thickness = 2.5
    UIStroke.Color = Color3.new(0,0,0)
    return label
end

local UserLabel = createLabel('UserLabel', Player.Name:upper(), Color3.new(1, 1, 1), 1)
local TimeLabel = createLabel('TimeLabel', 'TIME: 00:00:00', Color3.fromRGB(200, 200, 200), 2)
local FPSLabel = createLabel('FPSLabel', 'FPS: 0', Color3.fromRGB(255, 180, 0), 3)
local ClicksLabel = createLabel('ClicksLabel', 'CLICKS: 0', Color3.fromRGB(0, 255, 255), 4)
local EggsLabel = createLabel('EggsLabel', 'EGGS: 0', Color3.fromRGB(255, 255, 0), 5)
local EggsMinLabel = createLabel('EggsMinLabel', 'EGGS/MIN: 0', Color3.fromRGB(255, 150, 0), 6)
local RarestLabel = createLabel('RarestLabel', 'RAREST: 0', Color3.fromRGB(255, 0, 255), 7)
local RebirthsLabel = createLabel('RebirthsLabel', 'REBIRTHS: 0', Color3.fromRGB(0, 255, 0), 8)

--// LOGIC TÍNH TOÁN
local startTime = os.time()
local initialEggs = nil
local totalEggsGained = 0

local function updateLeaderstats()
    local leaderstats = Player:WaitForChild("leaderstats", 20)
    if not leaderstats then return end

    local function setupStat(statName, label, prefix)
        local stat = leaderstats:FindFirstChild(statName)
        if not stat then return end

        if statName == "Eggs" and initialEggs == nil then
            initialEggs = stat.Value
        end

        stat:GetPropertyChangedSignal("Value"):Connect(function()
            if statName == "Eggs" then
                -- Tính tổng trứng thực tế đã nhận (bao gồm cả +232 mỗi lần)
                totalEggsGained = stat.Value - (initialEggs or stat.Value)
                label.Text = "EGGS: " .. tostring(stat.Value) .. " (+" .. tostring(totalEggsGained) .. ")"
            elseif statName == "Rarest" then
                label.Text = "RAREST: " .. tostring(stat.Value)
            else
                label.Text = prefix .. ": " .. tostring(stat.Value)
            end
        end)
        
        -- Cập nhật lần đầu
        if statName == "Eggs" then
            label.Text = "EGGS: " .. tostring(stat.Value) .. " (+0)"
        elseif statName == "Rarest" then
            label.Text = "RAREST: " .. tostring(stat.Value)
        else
            label.Text = prefix .. ": " .. tostring(stat.Value)
        end
    end

    setupStat("Clicks", ClicksLabel, "CLICKS")
    setupStat("Eggs", EggsLabel, "EGGS")
    setupStat("Rarest", RarestLabel, "RAREST")
    setupStat("Rebirths", RebirthsLabel, "REBIRTHS")
end

task.spawn(updateLeaderstats)

--// VÒNG LẶP CẬP NHẬT FPS, TIME & EPM
local lastUpdate = tick()
local frames = 0
game:GetService("RunService").RenderStepped:Connect(function()
    frames = frames + 1
    local now = tick()
    
    -- Cập nhật FPS và EGGS/MIN mỗi giây
    if now - lastUpdate >= 1 then
        FPSLabel.Text = "FPS: " .. tostring(frames)
        
        local elapsed = os.time() - startTime
        if elapsed > 0 then
            -- Công thức: (Tổng trứng nhận được / Số giây đã trôi qua) * 60 giây
            local epm = math.floor((totalEggsGained / elapsed) * 60)
            EggsMinLabel.Text = "EGGS/MIN: " .. tostring(epm)
        end
        
        frames = 0
        lastUpdate = now
    end
    
    local elapsed = os.time() - startTime
    local hours = math.floor(elapsed / 3600)
    local mins = math.floor((elapsed % 3600) / 60)
    local secs = elapsed % 60
    TimeLabel.Text = string.format('TIME: %02d:%02d:%02d', hours, mins, secs)
end)

--// AUTO CLICK PHÍM P
task.spawn(function()
    local VIM = game:GetService("VirtualInputManager")
    while true do
        VIM:SendKeyEvent(true, Enum.KeyCode.P, false, game)
        task.wait(0.1)
        VIM:SendKeyEvent(false, Enum.KeyCode.P, false, game)
        task.wait(50)
    end
end)

local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

for _, gui in ipairs(playerGui:GetChildren()) do
    if gui:IsA("ScreenGui") then
        gui.Enabled = false
    end
end
----------------
--end
