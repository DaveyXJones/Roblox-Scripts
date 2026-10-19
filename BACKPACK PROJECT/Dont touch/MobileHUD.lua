--==================================================
-- MobileHUD (ModuleScript)
-- PlayerController > Modules > MobileHUD
--
-- Responsive mobile controls for phones/tablets.
-- Works with the newer DayZ-style BackpackUI and
-- exposes a dedicated flashlight button.
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local MobileHUD = {}

local CFG = {
	BG_DEFAULT = { col = Color3.fromRGB(18, 24, 18), alpha = 0.82 },
	BG_FIRE = { col = Color3.fromRGB(35, 10, 10), alpha = 0.88 },
	BG_ADS = { col = Color3.fromRGB(10, 25, 50), alpha = 0.88 },
	BG_RELOAD = { col = Color3.fromRGB(35, 22, 5), alpha = 0.88 },
	BG_MODE = { col = Color3.fromRGB(22, 12, 42), alpha = 0.88 },
	BG_EQUIP = { col = Color3.fromRGB(10, 35, 18), alpha = 0.88 },
	BG_SPRINT = { col = Color3.fromRGB(18, 30, 18), alpha = 0.82 },
	BG_CYCLE = { col = Color3.fromRGB(20, 20, 40), alpha = 0.88 },
	BG_FLASH = { col = Color3.fromRGB(42, 34, 10), alpha = 0.88 },

	BORDER_DEFAULT = Color3.fromRGB(100, 130, 100),
	BORDER_FIRE = Color3.fromRGB(180, 50, 50),
	BORDER_ADS = Color3.fromRGB(50, 110, 190),
	BORDER_RELOAD = Color3.fromRGB(170, 110, 20),
	BORDER_MODE = Color3.fromRGB(120, 80, 190),
	BORDER_EQUIP = Color3.fromRGB(40, 140, 70),
	BORDER_SPRINT = Color3.fromRGB(80, 160, 80),
	BORDER_CYCLE = Color3.fromRGB(80, 100, 200),
	BORDER_FLASH = Color3.fromRGB(190, 155, 75),
	BORDER_FLASH_ON = Color3.fromRGB(255, 215, 110),

	TEXT_DEFAULT = Color3.fromRGB(190, 210, 190),
	TEXT_FIRE = Color3.fromRGB(220, 140, 140),
	TEXT_ADS = Color3.fromRGB(120, 170, 230),
	TEXT_RELOAD = Color3.fromRGB(220, 175, 80),
	TEXT_MODE = Color3.fromRGB(180, 145, 230),
	TEXT_EQUIP = Color3.fromRGB(110, 200, 130),
	TEXT_SPRINT = Color3.fromRGB(140, 220, 140),
	TEXT_CYCLE = Color3.fromRGB(160, 180, 240),
	TEXT_FLASH = Color3.fromRGB(238, 220, 170),
	TEXT_FLASH_ON = Color3.fromRGB(255, 235, 190),

	BORDER_ALPHA = 0.40,
	TEXT_SIZE = 11,
	CORNER_R = 6,
	CORNER_ROUND = 999,
	DOUBLE_TAP_TIME = 0.35,

	POS = {
		BAG = UDim2.new(0.02, 0, 0.10, 0),
		VIEW = UDim2.new(0.02, 0, 0.20, 0),
		FLASH = UDim2.new(0.02, 0, 0.30, 0),
		LEAN_LEFT = UDim2.new(0.02, 0, 0.66, 0),
		LEAN_RIGHT = UDim2.new(0.02, 0, 0.46, 0),
		CROUCH = UDim2.new(0.57, 0, 0.58, 0),
		PRONE = UDim2.new(0.66, 0, 0.58, 0),
		SLIDE = UDim2.new(0.61, 0, 0.76, 0),
		CYCLE = UDim2.new(0.75, 0, 0.10, 0),
		RELOAD = UDim2.new(0.79, 0, 0.27, 0),
		MODE = UDim2.new(0.88, 0, 0.27, 0),
		ADS = UDim2.new(0.79, 0, 0.47, 0),
		FIRE = UDim2.new(0.88, 0, 0.47, 0),
		SPRINT = UDim2.new(0.91, 0, 0.68, 0),
	},

	SZ = {
		BAG = Vector2.new(54, 28),
		VIEW = Vector2.new(58, 28),
		FLASH = Vector2.new(62, 28),
		LEAN_LEFT = Vector2.new(56, 32),
		LEAN_RIGHT = Vector2.new(56, 32),
		CROUCH = Vector2.new(60, 34),
		PRONE = Vector2.new(56, 34),
		SLIDE = Vector2.new(56, 34),
		CYCLE = Vector2.new(70, 32),
		RELOAD = Vector2.new(58, 38),
		MODE = Vector2.new(58, 38),
		ADS = Vector2.new(58, 48),
		FIRE = Vector2.new(68, 48),
		SPRINT = Vector2.new(62, 62),
	},
}

local player = Players.LocalPlayer

local gui = nil
local buttons = {}
local buttonMeta = {}
local character = nil
local isSprinting = false
local isBackpackOpen = false

local layoutConn = nil
local syncConn = nil
local sprintStartedConn = nil
local sprintMovedConn = nil
local sprintEndedConn = nil

local Movement = nil
local Weapon = nil
local Camera = nil
local Viewmodel = nil
local HUD = nil
local Inventory = nil
local Backpack = nil
local Equipment = nil
local Melee = nil
local Flashlight = nil
local RestoreWeaponSlot = nil
local UseHandsItem = nil

local COMBAT_BUTTONS = { "FIRE", "ADS", "RELOAD", "MODE" }
local SLOT_ORDER = { "primary", "secondary", "melee", "grenade", "utility" }

local function clamp(value, minValue, maxValue)
	if value < minValue then return minValue end
	if value > maxValue then return maxValue end
	return value
end

local function getViewportSize()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1280, 720)
end

local function getResponsiveScale()
	local viewport = getViewportSize()
	local shortEdge = math.max(1, math.min(viewport.X, viewport.Y))
	local aspect = viewport.X / math.max(1, viewport.Y)
	local scale = clamp(shortEdge / 720, 0.85, 1.35)
	if aspect < 1.45 then
		scale = scale * 0.94
	elseif aspect > 2.1 then
		scale = scale * 1.05
	end
	return clamp(scale, 0.82, 1.4)
end

local function enforceLandscape()
	pcall(function()
		StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
	end)
end

local function disconnectConn(conn)
	if conn then conn:Disconnect() end
	return nil
end

local function flashPress(name, pressCol)
	local info = buttons[name]
	if not info then return end
	info.stroke.Color = pressCol or Color3.fromRGB(255, 255, 255)
	info.stroke.Transparency = 0.10
	task.delay(0.14, function()
		if buttons[name] and buttons[name].stroke then
			buttons[name].stroke.Color = buttons[name].defaultBorder
			buttons[name].stroke.Transparency = buttons[name].defaultAlpha
		end
	end)
end

local function setButtonVisible(name, visible)
	local info = buttons[name]
	if info and info.frame then
		info.frame.Visible = visible
	end
end

local function setCombatVisible(visible)
	for _, name in ipairs(COMBAT_BUTTONS) do
		setButtonVisible(name, visible)
	end
end

local function makeButton(name, label, pos, size, bgCfg, borderCol, textCol, cornerRadius, textSize)
	local frame = Instance.new("Frame")
	frame.Name = name .. "_Frame"
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.Position = pos
	frame.BackgroundColor3 = bgCfg.col
	frame.BackgroundTransparency = bgCfg.alpha
	frame.BorderSizePixel = 0
	frame.ZIndex = 10
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, cornerRadius or CFG.CORNER_R)

	local stroke = Instance.new("UIStroke")
	stroke.Color = borderCol
	stroke.Thickness = 1.2
	stroke.Transparency = CFG.BORDER_ALPHA
	stroke.Parent = frame

	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.Text = label
	btn.TextColor3 = textCol
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = textSize or CFG.TEXT_SIZE
	btn.ZIndex = 11
	btn.AutoButtonColor = false
	btn.Parent = frame

	buttons[name] = {
		frame = frame,
		btn = btn,
		stroke = stroke,
		defaultBorder = borderCol,
		defaultAlpha = CFG.BORDER_ALPHA,
	}
	buttonMeta[name] = {
		position = pos,
		size = size,
		textSize = textSize or CFG.TEXT_SIZE,
		cornerRadius = cornerRadius or CFG.CORNER_R,
	}
	return btn
end

local function applyResponsiveLayout()
	if not gui then return end
	local scale = getResponsiveScale()
	for name, meta in pairs(buttonMeta) do
		local info = buttons[name]
		if info and info.frame and info.btn then
			local sx = math.floor(meta.size.X * scale + 0.5)
			local sy = math.floor(meta.size.Y * scale + 0.5)
			info.frame.Size = UDim2.fromOffset(sx, sy)
			info.btn.TextSize = math.floor(clamp(meta.textSize * scale, meta.textSize - 1, meta.textSize + 5))
			local radius = meta.cornerRadius
			local corner = info.frame:FindFirstChildOfClass("UICorner")
			if corner then
				if radius == CFG.CORNER_ROUND then
					corner.CornerRadius = UDim.new(1, 0)
				else
					corner.CornerRadius = UDim.new(0, math.floor(radius * scale + 0.5))
				end
			end
		end
	end
end

local function refreshCycleLabel()
	local info = buttons.CYCLE
	if not info or not Weapon or not Equipment then return end
	local slot = Weapon.GetActiveSlotName()
	local labels = { primary = "PRI", secondary = "SEC", melee = "MEL", grenade = "GRN", utility = "UTL", hands = "HND" }
	info.btn.Text = "SWP " .. (labels[slot] or string.upper(slot or "MEL"))
end

local function refreshFlashlightButton()
	local info = buttons.FLASH
	if not info then return end
	local on = Flashlight and Flashlight.IsOn and Flashlight.IsOn() or false
	info.btn.Text = on and "LAMP ON" or "LAMP"
	info.btn.TextColor3 = on and CFG.TEXT_FLASH_ON or CFG.TEXT_FLASH
	info.stroke.Color = on and CFG.BORDER_FLASH_ON or CFG.BORDER_FLASH
	info.defaultBorder = info.stroke.Color
	info.defaultAlpha = CFG.BORDER_ALPHA
	if on then
		info.frame.BackgroundTransparency = 0.74
	else
		info.frame.BackgroundTransparency = CFG.BG_FLASH.alpha
	end
end

local function refreshBackpackButton()
	local info = buttons.BAG
	if not info then return end
	if isBackpackOpen then
		info.btn.Text = "CLOSE"
		info.btn.TextColor3 = CFG.TEXT_FLASH
		info.stroke.Color = CFG.BORDER_FLASH
		info.defaultBorder = CFG.BORDER_FLASH
		info.frame.BackgroundTransparency = 0.74
	else
		info.btn.Text = "BAG"
		info.btn.TextColor3 = CFG.TEXT_DEFAULT
		info.stroke.Color = CFG.BORDER_DEFAULT
		info.defaultBorder = CFG.BORDER_DEFAULT
		info.frame.BackgroundTransparency = CFG.BG_DEFAULT.alpha
	end
	info.defaultAlpha = CFG.BORDER_ALPHA
end

local function refreshFireLabel()
	local info = buttons.FIRE
	if not info or not Weapon then return end
	if Flashlight and Flashlight.IsOn and Flashlight.IsOn() then
		info.btn.Text = "SAFE"
		info.btn.TextColor3 = CFG.TEXT_FLASH
		info.stroke.Color = CFG.BORDER_FLASH
		info.defaultBorder = CFG.BORDER_FLASH
		return
	end
	local slot = Weapon.GetActiveSlotName()
	if slot == "primary" or slot == "secondary" then
		info.btn.Text = "FIRE"
		info.btn.TextColor3 = CFG.TEXT_FIRE
		info.stroke.Color = CFG.BORDER_FIRE
	elseif slot == "hands" or slot == "grenade" then
		info.btn.Text = "USE"
		info.btn.TextColor3 = CFG.TEXT_FLASH
		info.stroke.Color = CFG.BORDER_FLASH
	else
		info.btn.Text = "ATK"
		info.btn.TextColor3 = CFG.TEXT_EQUIP
		info.stroke.Color = CFG.BORDER_EQUIP
	end
	info.defaultBorder = info.stroke.Color
end

local function cycleWeaponSlot()
	if not Equipment or not Weapon then return end
	if Flashlight and Flashlight.IsOn and Flashlight.IsOn() then return end

	local currentSlot = Weapon.GetActiveSlotName()
	local occupied = {}
	for _, slotName in ipairs(SLOT_ORDER) do
		if not Equipment.IsSlotEmpty(slotName) then
			table.insert(occupied, slotName)
		end
	end
	if #occupied == 0 then return end
	if #occupied == 1 then
		if RestoreWeaponSlot then
			RestoreWeaponSlot(occupied[1])
		else
			Weapon.SetActiveSlot(occupied[1])
		end
		return
	end

	local currentIndex = 0
	for i, slotName in ipairs(occupied) do
		if slotName == currentSlot then
			currentIndex = i
			break
		end
	end

	local nextIndex = (currentIndex % #occupied) + 1
	local nextSlot = occupied[nextIndex]
	if RestoreWeaponSlot then
		RestoreWeaponSlot(nextSlot)
	else
		Weapon.SetActiveSlot(nextSlot)
	end
end

local function toggleFlashlight()
	if not Flashlight then return end
	if Flashlight.IsOn() then
		Flashlight.TurnOff()
		local slotName = Flashlight.GetSavedSlot()
		if RestoreWeaponSlot then
			RestoreWeaponSlot(slotName)
		elseif Weapon then
			Weapon.SetActiveSlot(slotName)
		end
	else
		Flashlight.TurnOn()
	end
	refreshFlashlightButton()
	refreshFireLabel()
	refreshCycleLabel()
end

local function buildUI()
	if gui then
		gui:Destroy()
		gui = nil
		buttons = {}
		buttonMeta = {}
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "MobileHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")

	local btnBag = makeButton("BAG", "BAG", CFG.POS.BAG, CFG.SZ.BAG, CFG.BG_DEFAULT, CFG.BORDER_DEFAULT, CFG.TEXT_DEFAULT)
	btnBag.MouseButton1Click:Connect(function()
		flashPress("BAG")
		if Backpack and Backpack.Toggle then
			Backpack.Toggle()
			isBackpackOpen = Backpack.IsOpen and Backpack.IsOpen() or false
			setCombatVisible(not isBackpackOpen)
			refreshBackpackButton()
		end
	end)

	local btnView = makeButton("VIEW", "VIEW", CFG.POS.VIEW, CFG.SZ.VIEW, CFG.BG_DEFAULT, CFG.BORDER_DEFAULT, CFG.TEXT_DEFAULT)
	btnView.MouseButton1Click:Connect(function()
		flashPress("VIEW")
		if Camera and Camera.TogglePerson then Camera.TogglePerson() end
	end)

	local btnFlash = makeButton("FLASH", "LAMP", CFG.POS.FLASH, CFG.SZ.FLASH, CFG.BG_FLASH, CFG.BORDER_FLASH, CFG.TEXT_FLASH)
	btnFlash.MouseButton1Click:Connect(function()
		flashPress("FLASH", CFG.BORDER_FLASH_ON)
		toggleFlashlight()
	end)

	local btnLeanL = makeButton("LEAN_LEFT", "< LN", CFG.POS.LEAN_LEFT, CFG.SZ.LEAN_LEFT, CFG.BG_DEFAULT, CFG.BORDER_DEFAULT, CFG.TEXT_DEFAULT)
	btnLeanL.MouseButton1Down:Connect(function() flashPress("LEAN_LEFT"); if Movement and Movement.LeanLeft then Movement.LeanLeft() end end)
	btnLeanL.MouseButton1Up:Connect(function() if Movement and Movement.LeanStop then Movement.LeanStop() end end)

	local btnLeanR = makeButton("LEAN_RIGHT", "LN >", CFG.POS.LEAN_RIGHT, CFG.SZ.LEAN_RIGHT, CFG.BG_DEFAULT, CFG.BORDER_DEFAULT, CFG.TEXT_DEFAULT)
	btnLeanR.MouseButton1Down:Connect(function() flashPress("LEAN_RIGHT"); if Movement and Movement.LeanRight then Movement.LeanRight() end end)
	btnLeanR.MouseButton1Up:Connect(function() if Movement and Movement.LeanStop then Movement.LeanStop() end end)

	local btnCrouch = makeButton("CROUCH", "CROUCH", CFG.POS.CROUCH, CFG.SZ.CROUCH, CFG.BG_DEFAULT, CFG.BORDER_DEFAULT, CFG.TEXT_DEFAULT)
	btnCrouch.MouseButton1Click:Connect(function() flashPress("CROUCH"); if Movement and Movement.Crouch then Movement.Crouch() end end)

	local btnProne = makeButton("PRONE", "PRONE", CFG.POS.PRONE, CFG.SZ.PRONE, CFG.BG_DEFAULT, CFG.BORDER_DEFAULT, CFG.TEXT_DEFAULT)
	btnProne.MouseButton1Click:Connect(function() flashPress("PRONE"); if Movement and Movement.Prone then Movement.Prone() end end)

	local btnSlide = makeButton("SLIDE", "SLIDE", CFG.POS.SLIDE, CFG.SZ.SLIDE, CFG.BG_DEFAULT, CFG.BORDER_DEFAULT, CFG.TEXT_DEFAULT)
	btnSlide.MouseButton1Click:Connect(function() flashPress("SLIDE"); if Movement and Movement.Slide then Movement.Slide() end end)

	local btnCycle = makeButton("CYCLE", "SWP MEL", CFG.POS.CYCLE, CFG.SZ.CYCLE, CFG.BG_CYCLE, CFG.BORDER_CYCLE, CFG.TEXT_CYCLE)
	btnCycle.MouseButton1Click:Connect(function()
		flashPress("CYCLE", CFG.BORDER_CYCLE)
		cycleWeaponSlot()
		refreshCycleLabel()
		refreshFireLabel()
	end)

	local btnReload = makeButton("RELOAD", "RLOAD", CFG.POS.RELOAD, CFG.SZ.RELOAD, CFG.BG_RELOAD, CFG.BORDER_RELOAD, CFG.TEXT_RELOAD)
	btnReload.MouseButton1Click:Connect(function()
		if Flashlight and Flashlight.IsOn and Flashlight.IsOn() then return end
		flashPress("RELOAD", CFG.BORDER_RELOAD)
		if not Weapon or not Weapon.Reload then return end
		local activeSlot = Weapon.GetActiveSlotName()
		if activeSlot ~= "primary" and activeSlot ~= "secondary" then return end
		task.spawn(function()
			Weapon.Reload(
				function()
					if HUD and HUD.SetReloading then HUD.SetReloading(true) end
				end,
				function(current, max, noAmmo)
					local w = Weapon.GetActiveWeapon()
					if HUD and HUD.SetReloading then HUD.SetReloading(false) end
					if HUD and HUD.UpdateAmmo and w then HUD.UpdateAmmo(w.name, current, max) end
					if noAmmo and HUD and HUD.ShowNotif then HUD.ShowNotif("NO AMMO", 2.0) end
				end
			)
		end)
	end)

	local btnMode = makeButton("MODE", "MODE", CFG.POS.MODE, CFG.SZ.MODE, CFG.BG_MODE, CFG.BORDER_MODE, CFG.TEXT_MODE)
	btnMode.MouseButton1Click:Connect(function()
		if Flashlight and Flashlight.IsOn and Flashlight.IsOn() then return end
		flashPress("MODE", CFG.BORDER_MODE)
		if not Weapon or not Weapon.CycleFireMode then return end
		local activeSlot = Weapon.GetActiveSlotName()
		if activeSlot ~= "primary" and activeSlot ~= "secondary" then return end
		local modeName = Weapon.CycleFireMode()
		local w = Weapon.GetActiveWeapon()
		if HUD and HUD.UpdateFireMode and w then
			HUD.UpdateFireMode(w.fireModes, Weapon.GetFireModeIndex())
		end
		if HUD and HUD.ShowNotif then
			HUD.ShowNotif("[ " .. modeName .. " ]", 1.2)
		end
	end)

	local btnADS = makeButton("ADS", "ADS", CFG.POS.ADS, CFG.SZ.ADS, CFG.BG_ADS, CFG.BORDER_ADS, CFG.TEXT_ADS)
	btnADS.MouseButton1Down:Connect(function()
		if Flashlight and Flashlight.IsOn and Flashlight.IsOn() then return end
		flashPress("ADS", CFG.BORDER_ADS)
		if not Weapon then return end
		local activeSlot = Weapon.GetActiveSlotName()
		if activeSlot == "primary" or activeSlot == "secondary" then
			Weapon.EnterADS()
		elseif activeSlot == "melee" or (Equipment and Equipment.IsSlotEmpty and Equipment.IsSlotEmpty("hands")) then
			if Camera and Camera.EnterADS then Camera.EnterADS() end
			if HUD and HUD.ShowOTSDot then HUD.ShowOTSDot(true) end
		end
	end)
	btnADS.MouseButton1Up:Connect(function()
		if Flashlight and Flashlight.IsOn and Flashlight.IsOn() then return end
		if not Weapon then return end
		local activeSlot = Weapon.GetActiveSlotName()
		if activeSlot == "primary" or activeSlot == "secondary" then
			Weapon.ExitADS()
		elseif activeSlot == "melee" or (Equipment and Equipment.IsSlotEmpty and Equipment.IsSlotEmpty("hands")) then
			if Camera and Camera.ExitADS then Camera.ExitADS() end
			if HUD and HUD.ShowOTSDot then HUD.ShowOTSDot(false) end
		end
	end)

	local btnFire = makeButton("FIRE", "FIRE", CFG.POS.FIRE, CFG.SZ.FIRE, CFG.BG_FIRE, CFG.BORDER_FIRE, CFG.TEXT_FIRE, nil, CFG.TEXT_SIZE + 2)
	btnFire.MouseButton1Down:Connect(function()
		if Flashlight and Flashlight.IsOn and Flashlight.IsOn() then return end
		flashPress("FIRE", CFG.BORDER_FIRE)
		if not Weapon then return end
		local activeSlot = Weapon.GetActiveSlotName()
		if activeSlot == "primary" or activeSlot == "secondary" then
			Weapon.SetMouseHeld(true)
			local mode = Weapon.GetFireMode()
			if mode and mode.name ~= "Auto" then
				Weapon.Shoot(Viewmodel.GetMuzzle(), function(current, max)
					local w = Weapon.GetActiveWeapon()
					if HUD and HUD.UpdateAmmo and w then HUD.UpdateAmmo(w.name, current, max) end
					if Viewmodel and Viewmodel.Kick and w then
						Viewmodel.Kick(Weapon.GetIsADS(), w.hipCF, w.adsCF, Weapon.GetRecoilKick and Weapon.GetRecoilKick() or nil)
					end
					if current <= 0 and HUD and HUD.SetEmpty then HUD.SetEmpty() end
				end)
			end
		elseif activeSlot == "melee" or (Equipment and Equipment.IsSlotEmpty and Equipment.IsSlotEmpty("hands")) then
			if Melee and Melee.TryAttack then Melee.TryAttack() end
		else
			if UseHandsItem then
				UseHandsItem()
			elseif Melee and Melee.TryAttack then
				Melee.TryAttack()
			end
		end
	end)
	btnFire.MouseButton1Up:Connect(function()
		if not Weapon then return end
		local activeSlot = Weapon.GetActiveSlotName()
		if activeSlot == "primary" or activeSlot == "secondary" then
			Weapon.SetMouseHeld(false)
		end
	end)

	local btnSprint = makeButton("SPRINT", "RUN", CFG.POS.SPRINT, CFG.SZ.SPRINT, CFG.BG_SPRINT, CFG.BORDER_SPRINT, CFG.TEXT_SPRINT, CFG.CORNER_ROUND)
	btnSprint.MouseButton1Down:Connect(function()
		flashPress("SPRINT", CFG.BORDER_SPRINT)
		isSprinting = true
		if Movement and Movement.Run then Movement.Run() end
	end)
	btnSprint.MouseButton1Up:Connect(function()
		isSprinting = false
		if Movement and Movement.Walk then Movement.Walk() end
	end)

	applyResponsiveLayout()
	refreshBackpackButton()
	refreshFlashlightButton()
	refreshCycleLabel()
	refreshFireLabel()
end

local function startSprintLoop()
	sprintStartedConn = disconnectConn(sprintStartedConn)
	sprintMovedConn = disconnectConn(sprintMovedConn)
	sprintEndedConn = disconnectConn(sprintEndedConn)

	local leftTouchStart = nil
	local sprintDistance = 40

	sprintStartedConn = UserInputService.TouchStarted:Connect(function(touch, gpe)
		if gpe then return end
		if touch.Position.X < getViewportSize().X * 0.45 and not leftTouchStart then
			leftTouchStart = touch.Position
		end
	end)

	sprintMovedConn = UserInputService.TouchMoved:Connect(function(touch, gpe)
		if gpe or not leftTouchStart then return end
		if touch.Position.X > getViewportSize().X * 0.45 then return end
		local delta = (touch.Position - leftTouchStart).Magnitude
		if delta >= sprintDistance and not isSprinting then
			isSprinting = true
			if Movement and Movement.Run then Movement.Run() end
		elseif delta < sprintDistance and isSprinting then
			isSprinting = false
			if Movement and Movement.Walk then Movement.Walk() end
		end
	end)

	sprintEndedConn = UserInputService.TouchEnded:Connect(function(touch)
		if touch.Position.X < getViewportSize().X * 0.45 then
			leftTouchStart = nil
			if isSprinting then
				isSprinting = false
				if Movement and Movement.Walk then Movement.Walk() end
			end
		end
	end)
end

local function startWatchers()
	layoutConn = disconnectConn(layoutConn)
	syncConn = disconnectConn(syncConn)

	local camera = workspace.CurrentCamera
	if camera then
		layoutConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			enforceLandscape()
			applyResponsiveLayout()
		end)
	end

	syncConn = RunService.Heartbeat:Connect(function()
		if Backpack and Backpack.IsOpen then
			local open = Backpack.IsOpen()
			if open ~= isBackpackOpen then
				isBackpackOpen = open
				setCombatVisible(not open)
				refreshBackpackButton()
			end
		end
		refreshBackpackButton()
		refreshCycleLabel()
		refreshFireLabel()
		refreshFlashlightButton()
	end)
end

function MobileHUD.Init(movementMod, weaponMod, cameraMod, viewmodelMod, hudMod, inventoryMod, backpackMod, equipmentMod, meleeMod, flashlightMod, char, restoreWeaponFn, useHandsItemFn)
	Movement = movementMod
	Weapon = weaponMod
	Camera = cameraMod
	Viewmodel = viewmodelMod
	HUD = hudMod
	Inventory = inventoryMod
	Backpack = backpackMod
	Equipment = equipmentMod
	Melee = meleeMod
	Flashlight = flashlightMod
	character = char
	RestoreWeaponSlot = restoreWeaponFn
	UseHandsItem = useHandsItemFn

	enforceLandscape()
	buildUI()
	startSprintLoop()
	startWatchers()

	print("[MobileHUD] Initialized.")
end

function MobileHUD.UpdateCharacter(newChar)
	character = newChar
	enforceLandscape()
end

function MobileHUD.SetVisible(visible)
	if gui then gui.Enabled = visible end
end

return MobileHUD
