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
    ["Lightning Wyvern"] = 3
}

_G.AutoDelete = {
    -- Danh sách độ hiếm muốn giữ lại (Viết đúng tên rarity)
    ["SafeRarities"] = {
        "Secret I", "Secret II", "Secret III"
    },
    
    -- Danh sách tên Pet muốn giữ lại
    ["SafePetNames"] = {
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
        ["Lightning Wyvern"] = 6,
    }
}
_G.AutoRainbow = {
    ["Enabled"] = true,
    ["Pets"] = {
        ["Lightning Wyvern"] = 2,
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
local Signal = require(ReplicatedStorage.Modules.Signal)
local PortalsData = require(ReplicatedStorage.Game.Portals)

-------------

--------------
--- --- --- --- --- --- --- --- --- --- --- --- ---
-- [[ LUỒNG 1: AUTO TAP (HEARTBEAT) ]]
--- --- --- --- --- --- --- --- --- --- --- --- ---

-- 1. CHẶN UI TỪ GỐC (HOOKING) - Chỉ chạy 1 lần
if not _G.AntUIHooked then
    local oldFire = Signal.Fire
    Signal.Fire = function(name, ...)
        local args = {...}
        if name == "OpenMessage" and (args[1] == "Teleport") then
            return -- Chặn đứng bảng xác nhận
        end
        return oldFire(name, ...)
    end
    _G.AntUIHooked = true
end

local function SmartTeleportNoUI()
    local data = Replication.Data
    if not data or not data.Portals then return end

    -- 2. Tìm cổng cao nhất đã mở khóa
    local sortedPortals = {}
    for name, info in pairs(PortalsData) do
        table.insert(sortedPortals, {Name = name, Price = info.Price})
    end
    table.sort(sortedPortals, function(a, b) return a.Price > b.Price end)

    local targetPortalName = nil
    for _, portal in ipairs(sortedPortals) do
        if data.Portals[portal.Name] then
            targetPortalName = portal.Name
            break 
        end
    end

    -- 3. SO SÁNH ZONE HIỆN TẠI (Thay thế check khoảng cách)
    if targetPortalName then
        local currentZone = data.Zone or "Unknown"
        
        -- Nếu zone hiện tại đã là zone mạnh nhất thì dừng luôn
        if currentZone == targetPortalName then
            -- print("📍 Đã ở đúng Zone: " .. currentZone)
            return 
        end

        -- 4. THỰC THI TELEPORT
        print("🚀 Đang chuyển từ [" .. currentZone .. "] lên [" .. targetPortalName .. "]")
        
        -- Cập nhật local data trước để tránh loop
        data.Zone = targetPortalName
        
        -- Gửi lệnh lên Server
        task.spawn(function()
            Network:InvokeServer("TeleportZone", targetPortalName)
        end)
    end
end




task.spawn(function()
    while true do
        if _G.AutoTap == true then
            Network:FireServer("Tap", true,true,true)
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
    end
end

local function ApplyHatchAutoDelete()
    local RS = game:GetService("ReplicatedStorage")
    local Network = require(RS.Modules.Network)
    local EggsModule = require(RS.Game.Eggs)
    local PetStats = require(RS.Game.PetStats)
    
    -- Lấy dữ liệu trứng (Bypass lỗi call function line 711)
    local EggsData = (type(EggsModule) == "table" and EggsModule) or debug.getupvalues(EggsModule)[1] or {}
    local MasterDeleteList = {}

    print("\n--- 🔍 ĐANG THIẾT LẬP AUTO DELETE CHO TRỨNG ĐANG HATCH ---")

    -- Chỉ quét những trứng nằm trong _G.AutoHatch.Egg
    for eggName, isHatching in pairs(_G.AutoHatch.Egg) do
        if isHatching and EggsData[eggName] then
            local eggInfo = EggsData[eggName]
            local petsInEgg = eggInfo.Pets or eggInfo.Contents or eggInfo.List
            
            if type(petsInEgg) == "table" then
                local toDelete = {}
                
                for key, value in pairs(petsInEgg) do
                    local petName = (type(key) == "string" and key) or (type(value) == "table" and (value.Name or value[1])) or (type(value) == "string" and value)
                    
                    if petName then
                        local data = PetStats.AllPets and PetStats.AllPets[petName] or {}
                        local rarity = data.Rarity or data.Tier or "Unknown"
                        
                        local isSafe = table.find(_G.AutoDelete.SafeRarities, rarity) or table.find(_G.AutoDelete.SafePetNames, petName)

                        if not isSafe then
                            table.insert(toDelete, petName)
                        end
                    end
                end
                
                if #toDelete > 0 then
                    MasterDeleteList[eggName] = toDelete
                    print("✅ Đã lập danh sách xóa cho: " .. eggName .. " (" .. #toDelete .. " pets)")
                end
            end
        end
    end

    -- 3. GỬI LỆNH
    if next(MasterDeleteList) then
        Network:FireServer("AutoDelete", MasterDeleteList)
        print("🚀 Đã gửi cấu hình Auto Delete lên Server!")
    else
        warn("⚠ Không tìm thấy trứng hợp lệ trong AutoHatch hoặc không có pet để xóa.")
    end
end

-- Thực thi
ApplyHatchAutoDelete()
local function SmartFocusEquip()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Network = require(ReplicatedStorage.Modules.Network)
    local Replication = require(ReplicatedStorage.Game.Replication)
    
    if not _G.FocusEquip then return end
    local data = Replication.Data
    if not data or not data.Pets then return end

    local maxSlots = data.EquipLimit or 5 
    local HunterLimits = { ["Secret Hunter"] = 3, ["Rainbow Hunter"] = 99, ["Golden Hunter"] = 99 }
    
    -- 1. Lấy danh sách ID mạnh nhất từ Server
    local serverBestIds = Network:InvokeServer("EquipBest") or {}

    -- 2. Phân loại Pet Hunter
    local hunterFound = { ["Secret Hunter"] = {}, ["Rainbow Hunter"] = {}, ["Golden Hunter"] = {} }
    for id, pet in pairs(data.Pets) do
        local enchant = pet.Enchant or ""
        if hunterFound[enchant] then
            table.insert(hunterFound[enchant], id)
        end
    end

    -- 3. Xây dựng Đội hình Lý tưởng
    local idealList = {}
    local idealMap = {}

    local function addToIdeal(list, limit)
        local added = 0
        for _, id in ipairs(list) do
            if #idealList < maxSlots and added < limit and not idealMap[id] then
                table.insert(idealList, id)
                idealMap[id] = true
                added = added + 1
            end
        end
    end

    addToIdeal(hunterFound["Secret Hunter"], HunterLimits["Secret Hunter"])
    addToIdeal(hunterFound["Rainbow Hunter"], HunterLimits["Rainbow Hunter"])
    addToIdeal(hunterFound["Golden Hunter"], HunterLimits["Golden Hunter"])
    addToIdeal(serverBestIds, 99)

    -- 4. Kiểm tra thay đổi
    local currentlyEquipped = {}
    for id, pet in pairs(data.Pets) do
        if pet.Equipped then table.insert(currentlyEquipped, id) end
    end

    local needsChange = false
    if #currentlyEquipped ~= #idealList then
        needsChange = true
    else
        for _, id in ipairs(idealList) do
            if not data.Pets[id] or not data.Pets[id].Equipped then 
                needsChange = true 
                break 
            end
        end
    end

    -- 5. THỰC THI (SỬA LỖI GỬI LỆNH ĐƠN)
    if needsChange then
        print("🔄 Đang thiết lập lại đội hình tối ưu...")
        
        -- Dọn sạch để tránh lỗi kẹt slot
        Network:InvokeServer("UnequipAll")
        task.wait(0.3)

        -- Đeo từng con một để Server nhận diện đúng
        for i, id in ipairs(idealList) do
            task.spawn(function()
                local success = Network:InvokeServer("Equip", id)
                if success then
                    local p = data.Pets[id]
                    print(string.format("✅ Slot %d: %s [%s]", i, p.Name, p.Enchant or "None"))
                else
                    print(string.format("❌ Lỗi đeo Slot %d (ID: %s)", i, id))
                end
            end)
            task.wait(0.1) -- Delay siêu nhỏ để tránh spam
        end
        print("✨ Hoàn tất quá trình Equip.")
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
        task.wait(10)
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
    local MAX_INDEX_LIMIT = 99 -- Giới hạn index cao nhất ông muốn

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
    -- Kiểm tra cả Config Golden và bảng Safe của AutoDelete
    if not Config or not Config.Enabled or not _G.AutoDelete then return end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Replication = require(ReplicatedStorage.Game.Replication)
    local Network = require(ReplicatedStorage.Modules.Network)
    local Player = game.Players.LocalPlayer
    local Character = Player.Character
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    
    local RootPart = Character.HumanoidRootPart
    if not Replication.Data or not Replication.Data.Pets then return end
    
    -- 1. Tạo bảng tra cứu Safe Enchant nhanh
    local safeEnchants = {}
    for _, v in pairs(_G.AutoDelete.SafeEnchants or {}) do
        safeEnchants[v] = true
    end

    local inventory = Replication.Data.Pets
    local groups = {}
    local oldCFrame = RootPart.CFrame
    local needsToTeleport = false

    -- 2. Quét túi đồ và kiểm tra điều kiện (Bổ sung lọc Safe Enchant)
    for id, petData in pairs(inventory) do
        -- Lấy enchant hiện tại
        local currentEnchant = petData.Enchant or "None"

        -- Điều kiện cơ bản: Tier Normal, Không Lock, Không Đeo, KHÔNG nằm trong Safe Enchant
        if petData.Tier == "Normal" and not petData.Locked and not petData.Equipped and not safeEnchants[currentEnchant] then
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
        elseif safeEnchants[currentEnchant] and petData.Tier == "Normal" then
            -- Debug nhẹ để ông biết nó đã cứu được 1 con pet
            -- print("🛡️ Đã bỏ qua " .. petData.Name .. " vì có Enchant: " .. currentEnchant)
        end
    end

    -- 3. Kiểm tra xem có đủ pet để thực hiện ít nhất 1 lần ép không
    for _, data in pairs(groups) do
        if #data.ids >= data.required then
            needsToTeleport = true
            break
        end
    end

    -- 4. Thực hiện Teleport và Ép
    if needsToTeleport then
        print(">>> Đang Teleport về máy Golden...")
        RootPart.CFrame = CFrame.new(GOLDEN_MACHINE_POS)
        task.wait(0.7) -- Đợi server nhận vị trí

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

        task.wait(0.5)
        print(">>> Quay lại vị trí cũ...")
        RootPart.CFrame = oldCFrame
    end
end


local RAINBOW_MACHINE_POS = Vector3.new(1205.83, 668.98, -13383.21)

local function RunAutoRainbow()
    local Config = _G.AutoRainbow
    -- Check cả config máy và bảng Safe của AutoDelete
    if not Config or not _G.AutoDelete or not _G.AutoDelete.SafeEnchants then return end

    local Network = require(game:GetService("ReplicatedStorage").Modules.Network)
    local Replication = require(game:GetService("ReplicatedStorage").Game.Replication)
    local Player = game.Players.LocalPlayer
    local RootPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    
    if not RootPart or not Replication.Data or not Replication.Data.Pets then return end

    -- 1. Tạo bảng tra cứu Safe Enchant nhanh
    local safeEnchants = {}
    for _, v in pairs(_G.AutoDelete.SafeEnchants) do 
        safeEnchants[v] = true 
    end

    local oldCFrame = RootPart.CFrame
    local hasAction = false

    -- [ PHẦN 1: CLAIM ]
    local activeCrafts = Replication.Data.CraftingPets.Rainbow
    for slotId, data in pairs(activeCrafts) do
        if data.EndTime - workspace:GetServerTimeNow() <= 0 then
            if not hasAction then 
                RootPart.CFrame = CFrame.new(RAINBOW_MACHINE_POS) 
                task.wait(0.2)
            end
            Network:InvokeServer("ClaimRainbow", slotId)
            print('✅ Claimed Rainbow Slot:', slotId)
            hasAction = true
            task.wait(0.3)
        end
    end

    -- [ PHẦN 2: START ]
    activeCrafts = Replication.Data.CraftingPets.Rainbow
    local currentSlotsUsed = 0
    for _ in pairs(activeCrafts) do currentSlotsUsed = currentSlotsUsed + 1 end
    
    local maxSlots = 3 

    while currentSlotsUsed < maxSlots do
        local batch = {}
        local targetNameFound = nil
        local reqAmountNeeded = 0

        for targetName, reqAmount in pairs(Config.Pets) do
            local tempBatch = {}
            for id, data in pairs(Replication.Data.Pets) do
                -- LẤY ENCHANT ĐỂ KIỂM TRA
                local petEnchant = data.Enchant or "None"

                -- ĐIỀU KIỆN: Tier Golden, ko Lock, ko Đeo, đúng Tên VÀ KHÔNG PHẢI SAFE ENCHANT
                if data.Tier == "Golden" and not data.Locked and not data.Equipped 
                   and string.find(data.Name, targetName) 
                   and not safeEnchants[petEnchant] then -- << LỌC Ở ĐÂY
                    
                    table.insert(tempBatch, id)
                end
                
                if #tempBatch >= reqAmount then break end
            end

            if #tempBatch >= reqAmount then
                batch = tempBatch
                targetNameFound = targetName
                reqAmountNeeded = reqAmount
                break
            end
        end

        if targetNameFound then
            if not hasAction then 
                RootPart.CFrame = CFrame.new(RAINBOW_MACHINE_POS) 
                task.wait(0.2)
            end

            local success = Network:InvokeServer("StartRainbow", batch)
            if success then
                print('🚀 Started Rainbow for:', targetNameFound)
                hasAction = true
                currentSlotsUsed = currentSlotsUsed + 1
                
                -- Loại bỏ pet đã dùng khỏi data tạm để tránh trùng lặp
                for _, usedId in ipairs(batch) do
                    Replication.Data.Pets[usedId] = nil 
                end
                task.wait(0.5)
            else
                break 
            end
        else
            break
        end
    end

    if hasAction then
        task.wait(0.3)
        RootPart.CFrame = oldCFrame
    end
end


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
    -- Kiểm tra cấu hình cần thiết
    if not _G.AutoElectric or not _G.AutoDelete or not _G.AutoDelete.SafeEnchants then return end
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Replication = require(ReplicatedStorage.Game.Replication)
    local Network = require(ReplicatedStorage.Modules.Network)
    
    local Player = game.Players.LocalPlayer
    local Character = Player.Character
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    local RootPart = Character.HumanoidRootPart
    
    local inventory = Replication.Data and Replication.Data.Pets
    if not inventory then return end

    -- 1. Tạo bảng tra cứu Safe Enchant từ AutoDelete
    local safeEnchants = {}
    for _, v in pairs(_G.AutoDelete.SafeEnchants) do 
        safeEnchants[v] = true 
    end

    local groups = {}
    local hasEnoughToCraft = false

    -- 2. Duyệt kho và lọc Pet
    for id, pet in pairs(inventory) do
        local petName = pet.Name
        local petEnchant = pet.Enchant or "None"

        -- Kiểm tra điều kiện Craft và CHỈ SKIP nếu trúng Safe Enchant
        local isTargetForElectric = _G.AutoElectric[petName]
        local isRainbow = (pet.Tier == "Rainbow")
        local notElectric = (pet.Mutation ~= "Electric")
        local notLocked = (not pet.Locked)
        local notEquipped = (not pet.Equipped)
        
        -- Lọc Enchant quý ở đây
        local isSafeEnchant = safeEnchants[petEnchant]

        if isTargetForElectric and isRainbow and notElectric and notLocked and notEquipped 
           and not isSafeEnchant then -- << Chỉ lọc duy nhất Enchant
            
            if not groups[petName] then
                groups[petName] = {ids = {}, required = _G.AutoElectric[petName]}
            end
            table.insert(groups[petName].ids, id)
        end
    end

    -- 3. Kiểm tra số lượng và Teleport Craft
    for petName, data in pairs(groups) do
        if #data.ids >= data.required then
            hasEnoughToCraft = true
            break
        end
    end

    if hasEnoughToCraft then
        local oldCFrame = RootPart.CFrame
        
        -- Dịch chuyển tới máy Electric
        RootPart.CFrame = CFrame.new(ELECTRIC_MACHINE_POS)
        task.wait(0.7)

        for petName, data in pairs(groups) do
            while #data.ids >= data.required do
                local batch = {}
                for i = 1, data.required do
                    table.insert(batch, data.ids[1])
                    table.remove(data.ids, 1)
                end
                
                local success = Network:InvokeServer("CraftPets", batch)
                
                if success then
                    print('✅ Fuse Electric thành công: ' .. petName)
                else
                    warn("❌ Fuse thất bại: " .. petName)
                end
                
                task.wait(0.5)
            end
        end

        -- Quay lại chỗ cũ
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
        SmartTeleportNoUI()
        SmartCleanInventory()
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
