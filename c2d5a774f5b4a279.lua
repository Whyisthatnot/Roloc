while not game:IsLoaded() do task.wait() end

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

pcall(function()
    -- Tuỳ chọn: có thể tắt render 3D nếu cần tối ưu
    -- RunService:Set3dRenderingEnabled(false)

    local function clearTextures(v)
        if v:IsA("BasePart") and not v:IsA("MeshPart") then
            v.Material = "Plastic"
            v.Reflectance = 0
        elseif v:IsA("MeshPart") then
            v.Material = "Plastic"
            v.Reflectance = 0
            v.TextureID = ""
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
            v.Lifetime = NumberRange.new(0)
        elseif v:IsA("Explosion") then
            v.BlastPressure = 1
            v.BlastRadius = 1
        elseif v:IsA("Fire") or v:IsA("Smoke") or v:IsA("SpotLight") or v:IsA("Sparkles") then
            v.Enabled = false
        elseif v:IsA("SpecialMesh") then
            v.TextureId = ""
        elseif v:IsA("ShirtGraphic") then
            v.Graphic = 1
        elseif v:IsA("Shirt") or v:IsA("Pants") then
            v[v.ClassName .. "Template"] = ""
        end
    end

    for _, v in ipairs(Workspace:GetDescendants()) do
        clearTextures(v)
    end

    Workspace.DescendantAdded:Connect(function(v)
        clearTextures(v)
    end)

    -- ✅ Ẩn map nhưng giữ nền để không bị rơi
    local function hideMap()
        for _, obj in ipairs(Workspace:GetChildren()) do
            if not obj:IsA("Terrain") and
               not obj:IsA("Camera") and
               obj.Name ~= "Effects" and
               obj.Name ~= "Camera" and
               not Players:GetPlayerFromCharacter(obj) then

                for _, part in ipairs(obj:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Transparency = 1
                        -- Giữ CanCollide để không rơi
                    elseif part:IsA("Decal") or part:IsA("Texture") then
                        part.Transparency = 1
                    end
                end

                if obj:IsA("BasePart") then
                    obj.Transparency = 1
                    -- Giữ CanCollide để không rơi
                end
            end
        end
    end

    hideMap()

    -- ✅ Chống AFK kick
    local virtualUser = game:GetService("VirtualUser")
    if getconnections then
        for _, conn in pairs(getconnections(lp.Idled)) do
            conn:Disable()
        end
    else
        lp.Idled:Connect(function()
            virtualUser:Button2Down(Vector2.new(), workspace.CurrentCamera.CFrame)
            task.wait(1)
            virtualUser:Button2Up(Vector2.new(), workspace.CurrentCamera.CFrame)
        end)
    end
end)


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local player = Players.LocalPlayer
local animalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
local HttpService = game:GetService("HttpService")

-- Cập nhật chức năng kiểm tra số lượng người chơi
local function checkPlayerCountAndKick()
    -- Kiểm tra số lượng người chơi trên server
    local playerCount = #Players:GetPlayers()
    
    if playerCount >= 2 then
        -- Nếu có từ 2 người chơi trở lên, kick người chơi hiện tại ra khỏi server
        player:Kick("Đã có ít nhất 2 người chơi trên server, bạn đã bị đá ra.")
    end
end

-- Kiểm tra và kick khi kết nối game
task.spawn(function()
    while true do
        checkPlayerCountAndKick()  -- Kiểm tra số lượng người chơi và kick nếu cần
        task.wait(5)  -- Kiểm tra mỗi 5 giây
    end
end)

-- Settings
local buyingEnabled = false
local sellingEnable = false
local farmingEnabled = true

local rarityOrder = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
	Mythic = 5,
	["Brainrot God"] = 6,
	Secret = 7
}

local WEBHOOK_URL = "https://discord.com/api/webhooks/1326348381806788628/fIT83ECRZGUl5AuAFsRvQk_JjMsJVoJOwekEAr7KAHUAD6GZMxQmcEL4eRMv22KFSI3U" -- 🔁 Thay bằng webhook của bạn
local TAG_USER_ID = "679141731337240577" -- 🏷️ Thay bằng ID Discord user/role bạn muốn ping

local function resetCharacter()
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = 0
		else
			character:BreakJoints()
		end
	end
end
local playerPlot = nil

local function findClosestPlot()
	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:WaitForChild("HumanoidRootPart")
	local closestPlot = nil
	local shortestDistance = math.huge

	for _, plot in ipairs(workspace:WaitForChild("Plots"):GetChildren()) do
		if plot:FindFirstChild("PlotSign") then
			local dist = (hrp.Position - plot.PlotSign.Position).Magnitude
			if dist < shortestDistance then
				shortestDistance = dist
				closestPlot = plot
			end
		end
	end

	return closestPlot
end

local function getPlayerPlot()
	if not playerPlot or not playerPlot.Parent then
		playerPlot = findClosestPlot()
		if playerPlot then
			print("📌 Player plot identified as:", playerPlot.Name)
		else
			warn("❌ Could not determine player plot.")
		end
	end
	return playerPlot
end


local function UI()
	-- Ẩn Topbar
	pcall(function()
		game:GetService("StarterGui"):SetCore("TopbarEnabled", false)
	end)

	-- Hàm rút gọn số tiền
	local function shortenNumber(num)
		if num >= 1e12 then
			return string.format("%.1fT", num / 1e12)
		elseif num >= 1e9 then
			return string.format("%.1fB", num / 1e9)
		elseif num >= 1e6 then
			return string.format("%.1fM", num / 1e6)
		elseif num >= 1e3 then
			return string.format("%.1fK", num / 1e3)
		else
			return tostring(num)
		end
	end

	-- Tạo GUI full screen
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PetDisplayUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local bgFrame = Instance.new("Frame")
	bgFrame.Size = UDim2.new(1, 0, 1, 0)
	bgFrame.Position = UDim2.new(0, 0, 0, 0)
	bgFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	bgFrame.BorderSizePixel = 0
	bgFrame.Parent = screenGui

	local layout = Instance.new("UIListLayout", bgFrame)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 50) -- 👈 Kéo tất cả pet xuống 50 pixels
	padding.Parent = bgFrame
	layout.Padding = UDim.new(0, 6)

	-- Player Label ở giữa màn hình
	local playerLabel = Instance.new("TextLabel")
	playerLabel.Name = "PlayerName"
	playerLabel.Size = UDim2.new(1, -20, 0, 50) -- 👈 nhỏ lại
	playerLabel.Position = UDim2.new(0, 0, 0.4, 0) -- Giữa màn hình theo chiều dọc
	playerLabel.BackgroundTransparency = 1
	playerLabel.TextColor3 = Color3.new(1, 1, 1)
	playerLabel.Font = Enum.Font.GothamBlack
	playerLabel.TextScaled = true
	playerLabel.TextXAlignment = Enum.TextXAlignment.Center
	playerLabel.TextYAlignment = Enum.TextYAlignment.Center
	playerLabel.Text = "🐾 Player: " .. player.Name
	playerLabel.Parent = screenGui -- 👈 nằm riêng, không bị ảnh hưởng bởi layout

	-- Xoá các dòng pet cũ
	local function clearPetLines()
		for _, child in ipairs(bgFrame:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end

	-- Vòng lặp cập nhật
	task.spawn(function()
		while true do
			clearPetLines()

			-- Cập nhật cash
			local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
			if cash then
				playerLabel.Text = string.format("🐾 Player: %s | 💰 Cash: %s", player.Name, shortenNumber(cash.Value))
			end

			-- Duyệt pet
			local hasSecret = false
			local plot = getPlayerPlot()
			if plot then
				local podiums = plot:FindFirstChild("AnimalPodiums")
				if podiums then
					for _, podium in ipairs(podiums:GetChildren()) do
						local spawn = podium:FindFirstChild("Base") and podium.Base:FindFirstChild("Spawn")
						if spawn then
							local attach = spawn:FindFirstChild("Attachment")
							local overhead = attach and attach:FindFirstChild("AnimalOverhead")
							if overhead then
								local name = overhead:FindFirstChild("DisplayName") and overhead.DisplayName.Text or "???"
								local rarity = overhead:FindFirstChild("Rarity") and overhead.Rarity.Text or "???"
								local rawMutation = overhead:FindFirstChild("Mutation") and overhead.Mutation.Text or ""
								local mutation = (rawMutation == "{Mutation_Name}" or rawMutation == "") and "None" or rawMutation

								if rarity == "Secret" then hasSecret = true end

								local label = Instance.new("TextLabel", bgFrame)
								label.Size = UDim2.new(1, -20, 0, 15)
								label.BackgroundTransparency = 1
								label.TextColor3 = Color3.fromRGB(255, 255, 255)
								label.Font = Enum.Font.SourceSans
								label.TextScaled = true
								label.TextXAlignment = Enum.TextXAlignment.Left
								label.Text = string.format("🐾 %s | ⭐ %s | 🧬 %s ", name, rarity, mutation)
							end
						end
					end
				end
			end

			bgFrame.BackgroundColor3 = hasSecret and Color3.fromRGB(0, 255, 0) or Color3.new(0, 0, 0)

			task.wait(1)
		end
	end)
end
UI()
local function spinCam()
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera

	local radius = 11 -- bán kính quay quanh nhân vật
	local height = 5 -- độ cao của camera
	local speed = 0.25 -- tốc độ quay

	local angle = 0

	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local hrp = character.HumanoidRootPart
			camera.CameraType = Enum.CameraType.Scriptable

			-- Tính toán vị trí camera theo hình tròn
			angle += speed * dt
			local camX = hrp.Position.X + math.cos(angle) * radius
			local camZ = hrp.Position.Z + math.sin(angle) * radius
			local camY = hrp.Position.Y + height

			local camPosition = Vector3.new(camX, camY, camZ)

			-- Camera nhìn về trung tâm nhân vật
			camera.CFrame = CFrame.new(camPosition, hrp.Position)
		end
	end)
end

spinCam()
local function countEmptySlots()
	local plot = getPlayerPlot()
	if not plot then return 0 end
	local podiums = plot:FindFirstChild("AnimalPodiums")
	if not podiums then return 0 end

	local empty = 0
	for _, podium in ipairs(podiums:GetChildren()) do
		local spawn = podium:FindFirstChild("Base") and podium.Base:FindFirstChild("Spawn")
		if not (spawn and spawn:FindFirstChild("Attachment")) then
			empty += 1
		end
	end
	return empty
end

local function walkToSmooth(targetPart)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local hrp = character:WaitForChild("HumanoidRootPart")

	local stuckTimer = 0
	local lastPos = hrp.Position
	local maxStuckTime = 5

	while true do
		local distance = (hrp.Position - targetPart.Position).Magnitude
		if distance <= 6 then
			return true
		end

		humanoid:MoveTo(targetPart.Position)

		if (hrp.Position - lastPos).Magnitude < 0.5 then
			stuckTimer += 0.1
		else
			stuckTimer = 0
		end
		lastPos = hrp.Position

		if stuckTimer >= maxStuckTime then
			warn("🧱 Stuck during walk (", math.floor(distance), " studs left). Resetting...")
			resetCharacter()
			wait(5)
			return false
		end

		task.wait(0.1)
	end
end

 local function findBestPet()
	local cash = player.leaderstats.Cash.Value
	local candidates = {}

	-- Xác định ngưỡng tối thiểu để mua
	local minimumRarity = 0
	if cash >= 10000000 then
		minimumRarity = rarityOrder["Mythic"] + 1
	elseif cash >= 7000000 then
		minimumRarity = rarityOrder["Legendary"] + 1
	elseif cash >= 1000000 then
		minimumRarity = rarityOrder["Epic"] + 1
	elseif cash >= 100000 then
		minimumRarity = rarityOrder["Rare"] + 1
	elseif cash >= 10000 then
		minimumRarity = rarityOrder["Common"] + 1
	end

	for _, animal in ipairs(workspace.MovingAnimals:GetChildren()) do
		local hrp = animal:FindFirstChild("HumanoidRootPart")
		local overhead = hrp and hrp:FindFirstChild("Info") and hrp.Info:FindFirstChild("AnimalOverhead")
		local nameLabel = overhead and overhead:FindFirstChild("DisplayName")

		if hrp and nameLabel then
			local petName = nameLabel.Text
			local data = animalsData[petName]
			if data and data.Price <= cash then
				local petRarity = data.Rarity
				local petRarityValue = rarityOrder[petRarity] or 0

				if petRarityValue < minimumRarity then
					print("⛔ Skip pet:", petName, "| Rarity:", petRarity, "| Too weak for cash =", cash)
				else
					table.insert(candidates, {
						Name = petName,
						Price = data.Price,
						Rarity = petRarity,
						RarityValue = petRarityValue,
						HRP = hrp
					})
				end
			end
		end
	end

	if #candidates == 0 then
		print("❌ No suitable pets to buy at cash =", cash)
		return nil
	end

	table.sort(candidates, function(a, b)
		if a.RarityValue == b.RarityValue then
			return a.Price > b.Price
		end
		return a.RarityValue > b.RarityValue
	end)

	print("✅ Best pet to buy:", candidates[1].Name, "| Rarity:", candidates[1].Rarity)
	return candidates[1]
end


local function sendWebhook(petName, rarity, mutationText)
	local payload = {
		content = "<@" .. TAG_USER_ID .. "> 🎉 **Secret Pet Purchased!**",
		username = "🐾 Pet Logger",
		embeds = {{
			title = "BOUGHT A SECRET!",
			color = 0xff00ff,
			fields = {
				{ name = "🐶 Name", value = petName },
				{ name = "⭐ Rarity", value = rarity },
				{ name = "🧬 Mutation", value = mutationText or "None" }
			},
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
		}}
	}

	local jsonData = HttpService:JSONEncode(payload)

	pcall(function()
		HttpService:PostAsync(WEBHOOK_URL, jsonData, Enum.HttpContentType.ApplicationJson)
	end)
end

local function tryBuyPet(pet)
	buyingEnabled = true

	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or not pet.HRP then return end

	if (hrp.Position - pet.HRP.Position).Magnitude > 6 then
		if not walkToSmooth(pet.HRP) then return end
	end

	local prompt = pet.HRP:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		print("💰 Buying pet:", pet.Name)
		fireproximityprompt(prompt, 0)
		task.spawn(function()
			task.wait(prompt.HoldDuration or 2)
			fireproximityprompt(prompt, 1)
		end)
		wait(0.5)
		-- 🔔 Webhook nếu là Secret
		local data = animalsData[pet.Name]
		if data and data.Rarity == "Secret" then
			local overhead = pet.HRP:FindFirstChild("Info") and pet.HRP.Info:FindFirstChild("AnimalOverhead")
			local mutationText = "None"
			if overhead then
				local mut = overhead:FindFirstChild("Mutation")
				if mut and mut:IsA("TextLabel") and mut.Text ~= "{Mutation_Name}" then
					mutationText = mut.Text
				end
			end
			sendWebhook(pet.Name, data.Rarity, mutationText)
		end
		resetCharacter()
		wait(5)
		return true
	end
	return false
end


local function removeLowestRarityPet()
	farmingEnabled = false
	sellingEnable = true
	buyingEnabled = false
	print("🔁 [Farm] Starting removeLowestRarityPet...")
	local plot = getPlayerPlot()
	if not plot then return end
	local podiums = plot:FindFirstChild("AnimalPodiums")
	if not podiums then return end

	local cash = player.leaderstats.Cash.Value

	-- ❗ Giới hạn xoá theo Cash
	local allowedMaxRarity = nil
	if cash >= 50000000 then
		allowedMaxRarity = rarityOrder["Mythic"]
	elseif cash >= 7000000 then
		allowedMaxRarity = rarityOrder["Legendary"]
	elseif cash >= 1000000 then
		allowedMaxRarity = rarityOrder["Epic"]
	elseif cash >= 100000 then
		allowedMaxRarity = rarityOrder["Rare"]
	elseif cash >= 3000 then
		allowedMaxRarity = rarityOrder["Common"]
	end

	if not allowedMaxRarity then
		print("💰 Cash too low. Skip removing.")
		return false
	end

	local lowestRarity = math.huge
	local lowestGeneration = math.huge
	local targetSpawn = nil
	local targetPetName = "?"

	for _, podium in ipairs(podiums:GetChildren()) do
		local spawn = podium:FindFirstChild("Base") and podium.Base:FindFirstChild("Spawn")
		if spawn then
			local attachment = spawn:FindFirstChild("Attachment")
			local overhead = attachment and attachment:FindFirstChild("AnimalOverhead")

			if overhead then
				local nameLabel = overhead:FindFirstChild("DisplayName")
				local genLabel = overhead:FindFirstChild("Generation")

				if nameLabel and nameLabel:IsA("TextLabel") and genLabel and genLabel:IsA("TextLabel") then
					local petName = nameLabel.Text
					local data = animalsData[petName]
					local rarity = data and data.Rarity
					local rarityValue = rarity and rarityOrder[rarity]
					local generationValue = tonumber(string.match(genLabel.Text, "%d+")) or 0

					if rarityValue then
						if rarity == "Brainrot God" or rarity == "Secret" then
							print("🔒 Skip VIP pet:", petName)
						elseif rarityValue <= allowedMaxRarity then
							if
								rarityValue < lowestRarity or
								(rarityValue == lowestRarity and generationValue < lowestGeneration)
							then
								lowestRarity = rarityValue
								lowestGeneration = generationValue
								targetSpawn = spawn
								targetPetName = petName
							end
						else
							print("⛔ Too rare to remove:", petName, "(Rarity:", rarity, ")")
						end
					end
				end
			end
		end
	end

	if targetSpawn then
		print("🗑️ Removing pet:", targetPetName, "| Rarity =", lowestRarity, "| Generation =", lowestGeneration)
		if not walkToSmooth(targetSpawn) then return end

		local promptAttachment = targetSpawn:FindFirstChild("PromptAttachment")
		local prompt = promptAttachment and promptAttachment:FindFirstChildWhichIsA("ProximityPrompt")

		if prompt then
			fireproximityprompt(prompt, 0)
			task.wait(prompt.HoldDuration or 2)
			fireproximityprompt(prompt, 1)
			return true
		end
	else
		print("✅ No pet meets deletion criteria at current cash =", cash)
	end

	return false
end


local function claimCoinsAtAnimalPodiums()
	print("🔁 [Farm] Starting claimCoinsAtAnimalPodiums...")

	local plot = getPlayerPlot()
	if not plot then
		warn("❌ [Farm] No plot found!")
		return
	end

	local animalPodiums = plot:FindFirstChild("AnimalPodiums")
	if not animalPodiums then
		warn("❌ [Farm] No AnimalPodiums found in plot!")
		return
	end

	if not farmingEnabled and buyingEnabled then
		print("⛔ [Farm] Skipping farming. farmingEnabled =", farmingEnabled, " buyingEnabled =", buyingEnabled)
		return
	end
	
	for i = 1, 10 do
		local podium = animalPodiums:FindFirstChild(tostring(i))
		if podium and podium:FindFirstChild("Claim") and podium.Claim:FindFirstChild("Hitbox") then
			local hitboxPos = podium.Claim.Hitbox.Position
			print("🚶 [Farm] Walking to podium slot", i)

			local reached = walkToSmooth({Position = hitboxPos + Vector3.new(0, 2, 0)})
			if not reached then
				print("❌ [Farm] Stuck while walking to podium slot", i, ". Skipping...")
				resetCharacter()
				wait(5)
			end
			wait(0.2)

			local args = { i }
			print("💰 [Farm] Claiming coins from slot", i)
			ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net"):WaitForChild("RE/PlotService/ClaimCoins"):FireServer(unpack(args))
			wait(0.2)
		else
			print("⚠️ [Farm] Podium", i, "invalid or no Hitbox.")
		end
	end

	print("✅ [Farm] Finished claimCoinsAtAnimalPodiums.")
end

local currentEmptySlots = 0

task.spawn(function()
	while true do
		currentEmptySlots = countEmptySlots()
		task.wait(0.1) -- Update mỗi 0.1 giây
	end
end)

task.spawn(function()
	while true do

		if currentEmptySlots > 0 then
			print("🟢 [AUTO] Empty slot found. Attempting to buy pet...")
			local bestPet = findBestPet()

			if bestPet then
				if farmingEnabled then
					print("🛑 [AUTO] Stop farming — pet found to buy")
					farmingEnabled = false
				end
				tryBuyPet(bestPet)
			else
				print("🔍 [AUTO] No pet found to buy. Switching to farming.")
				farmingEnabled = true
				claimCoinsAtAnimalPodiums()
			end

		else
			print("🟡 [AUTO] No empty slots. Trying to remove weakest pet...")
			local removed = removeLowestRarityPet()
			if removed then
				print("🗑️ [AUTO] Pet removed successfully.")
			else
				print("🔒 [AUTO] No pet could be removed. Farming instead.")
				farmingEnabled = true
				claimCoinsAtAnimalPodiums()
			end
		end

		wait(0.5)
	end
end)
