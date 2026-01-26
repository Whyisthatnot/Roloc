setfpscap(5)
_G.AutoTap = true
_G.AutoRebirthMax = true
_G.AutoCollectQuest = true
_G.AutoBuyWorld = true
_G.AutoUpgrade = true
_G.AutoClaimRank = true 
_G.AutoElectricSpin = true
_G.AutoBuyPotion = true
_G.FocusEquip = true
_G.AutoElectric = {
    ["Electrical Glitch"] = 3
}
_G.AutoDelete = {
    -- Danh sách độ hiếm muốn giữ lại (Viết đúng tên rarity)
    ["SafeRarities"] = {
        "Secret I", "Secret II", "Secret III"
    },
    
    -- Danh sách tên Pet muốn giữ lại
    ["SafePetNames"] = {
        "Electrical Glitch", 
        "Lightning Wyvern",
    },
    
    -- Danh sách Enchant muốn giữ lại
    ["SafeEnchants"] = {
        "Secret Hunter", 
        "Golden Hunter", 
        "Rainbow Hunter", 
    }
}
_G.AutoPotion = {
    ["Enabled"] = true,
    ["Use"] = {
        "Tap",
        "Rebirth",
        "Gem",
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
        ["Electrical Glitch"] = 5,
    }
}
_G.AutoRainbow = {
    ["Enabled"] = true,
    ["Pets"] = {
        ["Electrical Glitch"] = 5,
    }
}

-- [[ SERVICES & MODULES ]]
local Players = game:GetService("Players")
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
local CollectionService = game:GetService("CollectionService")
local PortalsDB = require(ReplicatedStorage.Game.Portals) -- Database chứa Index đảo
local player = Players.LocalPlayer
-------------

--------------
--- --- --- --- --- --- --- --- --- --- --- --- ---
-- [[ LUỒNG 1: AUTO TAP (HEARTBEAT) ]]
--- --- --- --- --- --- --- --- --- --- --- --- ---

local function teleportToBestIslandSafe()
    local player = Players.LocalPlayer
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local rootPart = character.HumanoidRootPart
    local data = Replication.Data
    
    if not data or not data.Portals then 
        warn("Dữ liệu game chưa load!")
        return 
    end

    local bestIslandPart = nil
    local maxDistance = -1
    local unlockedIslands = data.Portals

    -- Tìm đảo mạnh nhất đã mở khóa
    for _, part in ipairs(CollectionService:GetTagged("IslandPart")) do
        if unlockedIslands[part.Name] then
            local dist = part.Position.Magnitude
            if dist > maxDistance then
                maxDistance = dist
                bestIslandPart = part
            end
        end
    end

    if bestIslandPart then
        rootPart.Velocity = Vector3.zero
        -- Dịch chuyển lên cao 25 block để an toàn tuyệt đối
        rootPart.CFrame = CFrame.new(bestIslandPart.Position + Vector3.new(0, 75, 0))
        -- Khóa nhân vật lại trên không
        rootPart.Anchored = true

        -- Đợi 1 giây để map load
        task.wait(1)

    else
        warn("Không tìm thấy đảo nào hợp lệ!")
    end
end



task.spawn(function()
    while true do
        if _G.AutoTap == true then
            for i = 1,2 do
                Network:FireServer("Tap", true , false, false)
            end
            Network:FireServer("Tap", true , false, true)
        end
        task.wait(0.1) -- giảm lag, FPS thấp vẫn ổn
    end
end)
local function SmartCleanInventory()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Network = require(ReplicatedStorage.Modules.Network)
    local Replication = require(ReplicatedStorage.Game.Replication)
    local PetStats = require(ReplicatedStorage.Game.PetStats)

    local inventory = Replication.Data and Replication.Data.Pets
    if not inventory then return end

    -- Chuyển đổi List sang Map để script check nhanh hơn (Optimization)
    local function ToMap(list)
        local t = {}
        for _, v in pairs(list) do t[v] = true end
        return t
    end

    local RarityMap = ToMap(_G.AutoDelete.SafeRarities)
    local PetNameMap = ToMap(_G.AutoDelete.SafePetNames)
    local EnchantMap = ToMap(_G.AutoDelete.SafeEnchants)

    local idsToDelete = {}

    for id, data in pairs(inventory) do
        local stats = PetStats:GetStats(data.Name)
        local trueRarity = stats and stats.Rarity or "Common"
        local currentEnchant = data.Enchant or ""
        
        -- KIỂM TRA ĐIỀU KIỆN GIỮ (WHITELIST)
        local isSafe = (
            data.Equipped or 
            data.Locked or 
            PetNameMap[data.Name] or 
            RarityMap[trueRarity] or 
            EnchantMap[currentEnchant]
        )

        -- Nếu không an toàn thì mới cho vào danh sách xóa
        if not isSafe then
            table.insert(idsToDelete, id)
        end
    end

    -- THỰC THI XÓA
    if #idsToDelete > 0 then
        local success = Network:InvokeServer("DeletePet", idsToDelete)
        
        if not success then
            -- Backup nếu gửi cả cụm bị lỗi
            for _, petId in pairs(idsToDelete) do
                task.spawn(function() Network:InvokeServer("DeletePet", petId) end)
            end
        end
    else
    end
end
local function SmartFocusEquip()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Network = require(ReplicatedStorage.Modules.Network)
    local Replication = require(ReplicatedStorage.Game.Replication)
    local PetStats = require(ReplicatedStorage.Game.PetStats)

    if not _G.FocusEquip then return end

    local data = Replication.Data
    if not data or not data.Pets then return end

    -- 1. Cấu hình
    local maxSlots = data.EquipLimit or 3
    local HunterLimits = { ["Secret Hunter"] = 3, ["Rainbow Hunter"] = 99, ["Golden Hunter"] = 99 }
    
    -- Định nghĩa trọng số độ hiếm (Càng cao càng ưu tiên)
    local RarityWeight = {
        ["Secret III"] = 10, ["Secret II"] = 9, ["Secret I"] = 8,
        ["Mythical"] = 7, ["Legendary"] = 6, ["Epic"] = 5,
        ["Rare"] = 4, ["Uncommon"] = 3, ["Common"] = 2
    }

    local hunterFound = { ["Secret Hunter"] = {}, ["Rainbow Hunter"] = {}, ["Golden Hunter"] = {} }
    local others = {}

    -- 2. Phân loại và lấy thuộc tính so sánh
    for id, pet in pairs(data.Pets) do
        local stats = PetStats:GetStats(pet.Name)
        local rarityName = stats and stats.Rarity or "Common"
        
        local petObj = {
            id = id, 
            name = pet.Name, 
            enchant = pet.Enchant or "",
            multi = pet.Multi1 or 0, -- Lấy Multi1 để so sánh
            rarityVal = RarityWeight[rarityName] or 1 -- Quy đổi rarity sang số
        }
        
        if hunterFound[petObj.enchant] then
            table.insert(hunterFound[petObj.enchant], petObj)
        else
            table.insert(others, petObj)
        end
    end

    -- 3. HÀM SO SÁNH THÔNG MINH (Dành cho Pet không phải Hunter)
    local function ComparePets(a, b)
        -- Nếu Multi1 khác nhau, con nào Multi cao hơn thắng
        if a.multi ~= b.multi then
            return a.multi > b.multi
        end
        -- Nếu Multi1 bằng nhau, con nào Rarity cao hơn thắng
        return a.rarityVal > b.rarityVal
    end

    -- Sắp xếp các danh sách
    for _, list in pairs(hunterFound) do 
        table.sort(list, ComparePets) 
    end
    table.sort(others, ComparePets)

    -- 4. Xác định danh sách ID "Lý tưởng"
    local idealEquipMap = {}
    local idealCount = 0

    local function addToIdeal(list, limit)
        local added = 0
        for _, pet in ipairs(list) do
            if idealCount < maxSlots and added < limit then
                idealEquipMap[pet.id] = true
                idealCount = idealCount + 1
                added = added + 1
            end
        end
    end

    addToIdeal(hunterFound["Secret Hunter"], HunterLimits["Secret Hunter"])
    addToIdeal(hunterFound["Rainbow Hunter"], HunterLimits["Rainbow Hunter"])
    addToIdeal(hunterFound["Golden Hunter"], HunterLimits["Golden Hunter"])
    addToIdeal(others, 99)

    -- 5. KIỂM TRA & UNEQUIP PET SAI
    local toUnequip = {}
    for id, pet in pairs(data.Pets) do
        if pet.Equipped and not idealEquipMap[id] then
            table.insert(toUnequip, id)
        end
    end

    if #toUnequip > 0 then
        for _, id in ipairs(toUnequip) do
            task.spawn(function() Network:InvokeServer("Unequip", id) end)
        end
        task.wait(0.3)
    end

    -- 6. EQUIP BỔ SUNG
    local toEquipFinal = {}
    for id, _ in pairs(idealEquipMap) do
        if not data.Pets[id].Equipped then
            table.insert(toEquipFinal, id)
        end
    end

    if #toEquipFinal > 0 then
        local success = Network:InvokeServer("Equip", toEquipFinal)
        if not success then
            for _, id in ipairs(toEquipFinal) do
                task.spawn(function() Network:InvokeServer("Equip", id) end)
            end
        end
    end
end



task.spawn(function()
    while true do
        pcall(function()
            SmartCleanInventory()
        end)
        task.wait()
    end
end)
task.spawn(function()
    while true do
        pcall(function()
            local Network = require(game:GetService("ReplicatedStorage").Modules.Network)
            if _G.FocusEquip then
                SmartFocusEquip()
            else
                Network:InvokeServer("EquipBest")
            end
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
    local MAX_INDEX_LIMIT = 23 -- Giới hạn index cao nhất ông muốn

    while task.wait(0.5) do 
        local data = Replication.Data
        if not data or not data.Statistics then continue end

        -- 1. Auto Rebirth Logic
        if _G.AutoRebirthMax == true and not _G.IsRebirthing then
            local options = data.RebirthOptions
            local rawMaxIdx = (type(options) == "table" and #options) or (tonumber(options) or 0)
            local startIdx = math.min(rawMaxIdx, MAX_INDEX_LIMIT) 

            -- Kiểm tra giá của cái CAO NHẤT (Index 23)
            local topRbAmount = Rebirths:fromIndex(startIdx)
            local topBasePrice = Rebirths:getPrice(topRbAmount)
            local topFinalPrice = Rebirths:ClicksPrice(topBasePrice, data.Statistics.Rebirths)

            local shouldRebirth = false
            local targetIdx = 0

            -- ĐIỀU KIỆN 1: Nếu ĐỦ TIỀN mua cái cao nhất -> Mua luôn
            if data.Statistics.Clicks >= topFinalPrice then
                shouldRebirth = true
                targetIdx = startIdx
            -- ĐIỀU KIỆN 2: Nếu CHƯA ĐỦ cái cao nhất, nhưng đã QUÁ 60 GIÂY -> Tìm cái cao nhất trong tầm tiền
            elseif (tick() - lastRebirthTick >= 60) then
                for i = startIdx, 1, -1 do
                    local rbAmount = Rebirths:fromIndex(i)
                    local basePrice = Rebirths:getPrice(rbAmount)
                    local finalPrice = Rebirths:ClicksPrice(basePrice, data.Statistics.Rebirths)

                    if data.Statistics.Clicks >= finalPrice then
                        targetIdx = i
                        shouldRebirth = true
                        break 
                    end
                end
            end

            -- Thực hiện Rebirth nếu thỏa mãn 1 trong 2 điều kiện trên
            if shouldRebirth and targetIdx > 0 then
                _G.IsRebirthing = true 
                
                local success = pcall(function()
                    return Network:InvokeServer("Rebirth", targetIdx)
                end)
                
                if success then
                    lastRebirthTick = tick() -- Reset đồng hồ
                end
                
                task.wait(0.2)
                _G.IsRebirthing = false 
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
        print(">>> Đang Teleport về máy Golden...")
        RootPart.CFrame = CFrame.new(GOLDEN_MACHINE_POS)
        RootPart.Anchored = false

        task.wait(0.1) -- Đợi server nhận vị trí

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
                end
            end
        end

        RootPart.CFrame = oldCFrame
    end
end

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
        RootPart.Anchored = false

        task.wait()

        for slotId, data in pairs(activeCrafts) do
            if data.EndTime - workspace:GetServerTimeNow() <= 0 then
                Network:InvokeServer("ClaimRainbow", slotId)
                print('claim rainbow')
                hasAction = true
                task.wait(0.5)
            end
        end

        if canCraft and slotCount < 3 then
            local success = Network:InvokeServer("StartRainbow", batch)
            print('start rainbow')
            if success then
                hasAction = true
            end
        end

        if hasAction then
            task.wait(0.5)
            RootPart.CFrame = oldCFrame
        end
    end
end


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

local ELECTRIC_MACHINE_POS = Vector3.new(-99.08, 209.93 + 3, 205.80)

local function startAutoCraftElectric()
    if not _G.AutoElectric then return end
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Replication = require(ReplicatedStorage.Game.Replication)
    local Network = require(ReplicatedStorage.Modules.Network)
    local Signal = require(ReplicatedStorage.Modules.Signal)
    
    local Player = game.Players.LocalPlayer
    local Character = Player.Character
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    local RootPart = Character.HumanoidRootPart
    
    local inventory = Replication.Data and Replication.Data.Pets
    if not inventory then return end

    local groups = {}
    local hasEnoughToCraft = false

    -- Bước 1: Thu thập và kiểm tra điều kiện
    for id, pet in pairs(inventory) do
        -- Điều kiện: Tên trong Config, Tier Rainbow, chưa có Mutation Electric, ko Lock, ko Đang đeo
        if _G.AutoElectric[pet.Name] and pet.Tier == "Rainbow" and pet.Mutation ~= "Electric" and not pet.Locked and not pet.Equipped then
            if not groups[pet.Name] then
                groups[pet.Name] = {ids = {}, required = _G.AutoElectric[pet.Name]}
            end
            table.insert(groups[pet.Name].ids, id)
        end
    end

    -- Kiểm tra xem có nhóm nào đủ số lượng để craft không
    for petName, data in pairs(groups) do
        if #data.ids >= data.required then
            hasEnoughToCraft = true
            break
        end
    end

    -- Bước 2: Nếu đủ pet thì mới Teleport và thực hiện Craft
    if hasEnoughToCraft then
        local oldCFrame = RootPart.CFrame -- Lưu vị trí cũ
        
        RootPart.CFrame = CFrame.new(ELECTRIC_MACHINE_POS)
        task.wait()
        RootPart.Anchored = false

        task.wait(0.7) -- Đợi server cập nhật vị trí

        for petName, data in pairs(groups) do
            while #data.ids >= data.required do
                local batch = {}
                for i = 1, data.required do
                    table.insert(batch, data.ids[1])
                    table.remove(data.ids, 1)
                end
                
                
                -- Gửi lệnh Craft lên Server
                local success = Network:InvokeServer("CraftPets", batch)
                
                if success then
                    print('craft electric: ' .. petName)
                else
                    warn("❌ Chế tạo thất bại: " .. petName)
                end
                
                task.wait(0.5) -- Tránh spam remote
            end
        end

        -- Quay về vị trí cũ sau khi xong việc
        task.wait(0.5)
        RootPart.CFrame = oldCFrame
    end
end
--------------------------

-- Vòng lặp kiểm tra mỗi 10 giây
task.spawn(function()
    while true do
        if _G.AutoGoldenConfig and _G.AutoGoldenConfig.Enabled then
            print("Golden")

            RunAutoCraftGolden()
        end
        if _G.AutoRainbow and _G.AutoRainbow.Enabled then
            print("Rainbow")
            RunAutoRainbow()
        end
        if _G.AutoElectric and next(_G.AutoElectric) ~= nil then
            print("Electric")
            startAutoCraftElectric()
        end
        teleportToBestIslandSafe()
        task.wait(1)
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
Background.BorderSizePixel = 0.5

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

----------------
--ends
