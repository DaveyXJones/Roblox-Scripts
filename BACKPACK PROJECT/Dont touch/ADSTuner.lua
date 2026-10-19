--==================================================
-- ADSTuner
-- LocalScript ? StarterPlayerScripts
--
-- Live CFrame tuner for weapon viewmodel positions.
-- Uses numpad keys to adjust hip or ADS position in
-- real-time, then prints the final values to Output
-- so you can paste them into WeaponConfig.
--
-- CONTROLS:
--   T          = Toggle tuner on/off
--   H         = Switch between HIP / ADS / AXIS mode
--   P         = Print current values to Output
--
--   Numpad 8    = Move forward  (-Z)
--   Numpad 5    = Move backward (+Z)
--   Numpad 4    = Move left     (-X)
--   Numpad 6    = Move right    (+X)
--   Numpad 9    = Move up       (+Y)
--   Numpad 7    = Move down     (-Y)
--
--   Numpad +    = Rotate positive (axis depends on mode)
--   Numpad -    = Rotate negative
--   Numpad 1    = Select X rotation axis
--   Numpad 2    = Select Y rotation axis
--   Numpad 3    = Select Z rotation axis
--
--   Numpad 0    = Reset current mode to default
--   Numpad .    = Toggle step size (fine / normal / coarse)
--
-- REMOVE THIS SCRIPT BEFORE SHIPPING.
--==================================================
---------------DEV MODE TOGGLE-------
local DEV_MODE = false  -- set to false to disable tuner
if not DEV_MODE then return end

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")

-- Wait for modules to load
task.wait(3)

-- ============================================================
-- MODULE FINDER
-- ============================================================
local playerScripts = player:WaitForChild("PlayerScripts")
local moduleCache = {}

local function findModule(name)
	if moduleCache[name] then return moduleCache[name] end
	for _, desc in ipairs(playerScripts:GetDescendants()) do
		if desc:IsA("ModuleScript") and desc.Name == name then
			local ok, result = pcall(require, desc)
			if ok then moduleCache[name] = result; return result end
		end
	end
	for _, desc in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
		if desc:IsA("ModuleScript") and desc.Name == name then
			local ok, result = pcall(require, desc)
			if ok then moduleCache[name] = result; return result end
		end
	end
	return nil
end

-- ============================================================
-- STATE
-- ============================================================
local enabled = false
local mode    = "ADS"   -- "HIP", "ADS", or "AXIS"
local rotAxis = "Y"     -- which axis +/- rotates

-- Step sizes
local STEPS = {
	{ name = "FINE",   pos = 0.005, rot = 1   },
	{ name = "NORMAL", pos = 0.02,  rot = 5   },
	{ name = "COARSE", pos = 0.05,  rot = 15  },
}
local stepIndex = 2  -- start on NORMAL

-- Current tuning values (position + rotation separated for clarity)
local hipPos  = Vector3.new(0.30, -0.36, -0.50)
local hipRot  = Vector3.new(0, 0, 0)              -- degrees

local adsPos  = Vector3.new(-0.299, -0.35, -0.55)
local adsRot  = Vector3.new(0, 0, 0)              -- degrees

local axisRot = Vector3.new(0, 0, 0)              -- degrees (axisFix)

-- ============================================================
-- LOAD CURRENT VALUES FROM ACTIVE WEAPON
-- ============================================================
local function loadFromWeapon()
	local Weapon       = findModule("WeaponModule")
	local WeaponConfig = findModule("WeaponConfig")
	local Equipment    = findModule("EquipmentModule")

	if not Weapon or not WeaponConfig then return end

	local slotName = Weapon.GetActiveSlotName and Weapon.GetActiveSlotName()
	if not slotName then return end

	local weaponItem = Equipment and Equipment.GetSlot(slotName)
	if not weaponItem or not weaponItem.data or not weaponItem.data.assetName then return end

	local cfg = WeaponConfig.Get(weaponItem.data.assetName)
	if not cfg then return end

	-- Extract position and rotation from hipCF
	local hx, hy, hz = cfg.hipCF.X, cfg.hipCF.Y, cfg.hipCF.Z
	hipPos = Vector3.new(hx, hy, hz)

	-- Extract rotation (degrees) from hipCF
	local hrx, hry, hrz = cfg.hipCF:ToEulerAnglesXYZ()
	hipRot = Vector3.new(math.deg(hrx), math.deg(hry), math.deg(hrz))

	-- Extract position from adsCF
	local ax, ay, az = cfg.adsCF.X, cfg.adsCF.Y, cfg.adsCF.Z
	adsPos = Vector3.new(ax, ay, az)

	local arx, ary, arz = cfg.adsCF:ToEulerAnglesXYZ()
	adsRot = Vector3.new(math.deg(arx), math.deg(ary), math.deg(arz))

	-- Extract axisFix rotation
	if cfg.axisFix then
		local fx, fy, fz = cfg.axisFix:ToEulerAnglesXYZ()
		axisRot = Vector3.new(math.deg(fx), math.deg(fy), math.deg(fz))
	else
		axisRot = Vector3.new(0, 0, 0)
	end

	print("[ADSTuner] Loaded values from: " .. weaponItem.data.assetName)
end

-- ============================================================
-- BUILD CFrames FROM CURRENT VALUES
-- ============================================================
local function buildHipCF()
	return CFrame.new(hipPos)
		* CFrame.Angles(math.rad(hipRot.X), math.rad(hipRot.Y), math.rad(hipRot.Z))
end

local function buildAdsCF()
	return CFrame.new(adsPos)
		* CFrame.Angles(math.rad(adsRot.X), math.rad(adsRot.Y), math.rad(adsRot.Z))
end

local function buildAxisFix()
	return CFrame.Angles(math.rad(axisRot.X), math.rad(axisRot.Y), math.rad(axisRot.Z))
end

-- ============================================================
-- APPLY VALUES TO VIEWMODEL
-- ============================================================
local function apply()
	local Viewmodel = findModule("ViewmodelModule")
	if not Viewmodel then return end

	if mode == "HIP" then
		Viewmodel.SetTargetOverride(buildHipCF())
	elseif mode == "ADS" then
		Viewmodel.SetTargetOverride(buildAdsCF())
	elseif mode == "AXIS" then
		-- Axis fix changes require a rebuild — just print for now
		-- and apply on next equip
	end
end

-- ============================================================
-- GUI
-- ============================================================
local screenGui = Instance.new("ScreenGui", playerGui)
screenGui.Name         = "ADSTuner"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 1000
screenGui.Enabled      = false

local panel = Instance.new("Frame", screenGui)
panel.Size              = UDim2.new(0, 260, 0, 145)
panel.Position          = UDim2.new(1, -270, 0, 10)
panel.BackgroundColor3  = Color3.fromRGB(15, 18, 22)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel   = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)
local pStroke = Instance.new("UIStroke", panel)
pStroke.Color     = Color3.fromRGB(60, 160, 220)
pStroke.Thickness = 1.5

local title = Instance.new("TextLabel", panel)
title.Size              = UDim2.new(1, 0, 0, 22)
title.BackgroundColor3  = Color3.fromRGB(40, 110, 170)
title.BackgroundTransparency = 0.2
title.TextColor3        = Color3.fromRGB(255, 255, 255)
title.Font              = Enum.Font.GothamBold
title.TextSize          = 11
title.Text              = "ADS TUNER"
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 6)

local modeLabel = Instance.new("TextLabel", panel)
modeLabel.Size              = UDim2.new(1, -10, 0, 16)
modeLabel.Position          = UDim2.new(0, 5, 0, 26)
modeLabel.BackgroundTransparency = 1
modeLabel.TextColor3        = Color3.fromRGB(100, 200, 255)
modeLabel.Font              = Enum.Font.GothamBold
modeLabel.TextSize          = 10
modeLabel.TextXAlignment    = Enum.TextXAlignment.Left
modeLabel.Text              = "Mode: ADS"

local stepLabel = Instance.new("TextLabel", panel)
stepLabel.Size              = UDim2.new(1, -10, 0, 16)
stepLabel.Position          = UDim2.new(0, 5, 0, 42)
stepLabel.BackgroundTransparency = 1
stepLabel.TextColor3        = Color3.fromRGB(180, 180, 140)
stepLabel.Font              = Enum.Font.GothamBold
stepLabel.TextSize          = 10
stepLabel.TextXAlignment    = Enum.TextXAlignment.Left
stepLabel.Text              = "Step: NORMAL"

local rotAxisLabel = Instance.new("TextLabel", panel)
rotAxisLabel.Size              = UDim2.new(1, -10, 0, 16)
rotAxisLabel.Position          = UDim2.new(0, 5, 0, 58)
rotAxisLabel.BackgroundTransparency = 1
rotAxisLabel.TextColor3        = Color3.fromRGB(180, 160, 200)
rotAxisLabel.Font              = Enum.Font.GothamBold
rotAxisLabel.TextSize          = 10
rotAxisLabel.TextXAlignment    = Enum.TextXAlignment.Left
rotAxisLabel.Text              = "Rot Axis: Y  (+/- to rotate)"

local posLabel = Instance.new("TextLabel", panel)
posLabel.Size              = UDim2.new(1, -10, 0, 16)
posLabel.Position          = UDim2.new(0, 5, 0, 78)
posLabel.BackgroundTransparency = 1
posLabel.TextColor3        = Color3.fromRGB(200, 200, 200)
posLabel.Font              = Enum.Font.Code
posLabel.TextSize          = 9
posLabel.TextXAlignment    = Enum.TextXAlignment.Left
posLabel.Text              = "Pos: 0, 0, 0"

local rotLabel = Instance.new("TextLabel", panel)
rotLabel.Size              = UDim2.new(1, -10, 0, 16)
rotLabel.Position          = UDim2.new(0, 5, 0, 94)
rotLabel.BackgroundTransparency = 1
rotLabel.TextColor3        = Color3.fromRGB(200, 200, 200)
rotLabel.Font              = Enum.Font.Code
rotLabel.TextSize          = 9
rotLabel.TextXAlignment    = Enum.TextXAlignment.Left
rotLabel.Text              = "Rot: 0, 0, 0"

local hintLabel = Instance.new("TextLabel", panel)
hintLabel.Size              = UDim2.new(1, -10, 0, 24)
hintLabel.Position          = UDim2.new(0, 5, 1, -28)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3        = Color3.fromRGB(120, 120, 120)
hintLabel.Font              = Enum.Font.Gotham
hintLabel.TextSize          = 8
hintLabel.TextXAlignment    = Enum.TextXAlignment.Left
hintLabel.TextWrapped       = true
hintLabel.Text              = "T=toggle  H=mode  P=print  Num.=step  Num0=reset"

-- ============================================================
-- UPDATE DISPLAY
-- ============================================================
local function updateDisplay()
	local pos, rot
	if mode == "HIP" then
		pos = hipPos
		rot = hipRot
		modeLabel.Text = "Mode: HIP"
		modeLabel.TextColor3 = Color3.fromRGB(100, 220, 130)
	elseif mode == "ADS" then
		pos = adsPos
		rot = adsRot
		modeLabel.Text = "Mode: ADS"
		modeLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	elseif mode == "AXIS" then
		pos = Vector3.new(0, 0, 0)
		rot = axisRot
		modeLabel.Text = "Mode: AXIS FIX"
		modeLabel.TextColor3 = Color3.fromRGB(255, 180, 100)
	end

	stepLabel.Text = "Step: " .. STEPS[stepIndex].name
	rotAxisLabel.Text = "Rot Axis: " .. rotAxis .. "  (+/- to rotate)"

	local function fmt(n)
		return string.format("%.3f", n)
	end

	posLabel.Text = "Pos: " .. fmt(pos.X) .. ", " .. fmt(pos.Y) .. ", " .. fmt(pos.Z)
	rotLabel.Text = "Rot: " .. fmt(rot.X) .. "°, " .. fmt(rot.Y) .. "°, " .. fmt(rot.Z) .. "°"
end

-- ============================================================
-- PRINT VALUES (paste into WeaponConfig)
-- ============================================================
local function printValues()
	local Weapon    = findModule("WeaponModule")
	local Equipment = findModule("EquipmentModule")
	local slotName  = Weapon and Weapon.GetActiveSlotName and Weapon.GetActiveSlotName() or "?"
	local weapon    = Equipment and Equipment.GetSlot(slotName)
	local name      = weapon and weapon.data and weapon.data.assetName or "Unknown"

	local function fmt(n)
		return string.format("%.3f", n)
	end

	print("\n========== ADSTuner Output: " .. name .. " ==========")
	print("hipCF = CFrame.new(" .. fmt(hipPos.X) .. ", " .. fmt(hipPos.Y) .. ", " .. fmt(hipPos.Z) .. ")")

	if math.abs(hipRot.X) > 0.1 or math.abs(hipRot.Y) > 0.1 or math.abs(hipRot.Z) > 0.1 then
		print("    * CFrame.Angles(math.rad(" .. fmt(hipRot.X) .. "), math.rad(" .. fmt(hipRot.Y) .. "), math.rad(" .. fmt(hipRot.Z) .. ")),")
	else
		print(",")
	end

	print("adsCF = CFrame.new(" .. fmt(adsPos.X) .. ", " .. fmt(adsPos.Y) .. ", " .. fmt(adsPos.Z) .. ")")

	if math.abs(adsRot.X) > 0.1 or math.abs(adsRot.Y) > 0.1 or math.abs(adsRot.Z) > 0.1 then
		print("    * CFrame.Angles(math.rad(" .. fmt(adsRot.X) .. "), math.rad(" .. fmt(adsRot.Y) .. "), math.rad(" .. fmt(adsRot.Z) .. ")),")
	else
		print(",")
	end

	print("axisFix = CFrame.Angles(math.rad(" .. fmt(axisRot.X) .. "), math.rad(" .. fmt(axisRot.Y) .. "), math.rad(" .. fmt(axisRot.Z) .. ")),")
	print("=================================================\n")
end

-- ============================================================
-- INPUT HANDLING
-- ============================================================
local KEY = Enum.KeyCode

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	local keyCode = input.KeyCode

	-- T: Toggle tuner
	if keyCode == KEY.T then
		enabled = not enabled
		screenGui.Enabled = enabled
		if enabled then
			loadFromWeapon()
			updateDisplay()
			apply()
		end
		print("[ADSTuner] " .. (enabled and "ENABLED" or "DISABLED"))
		return
	end

	if not enabled then return end

	-- H: Cycle mode
	if keyCode == KEY.H then
		if mode == "HIP" then
			mode = "ADS"
		elseif mode == "ADS" then
			mode = "AXIS"
		else
			mode = "HIP"
		end
		updateDisplay()
		apply()
		return
	end

	-- P: Print values
	if keyCode == KEY.P then
		printValues()
		return
	end

	-- Numpad .: Cycle step size
	if keyCode == KEY.KeypadPeriod then
		stepIndex = (stepIndex % #STEPS) + 1
		updateDisplay()
		return
	end

	-- Numpad 1/2/3: Select rotation axis
	if keyCode == KEY.KeypadOne then
		rotAxis = "X"
		updateDisplay()
		return
	elseif keyCode == KEY.KeypadTwo then
		rotAxis = "Y"
		updateDisplay()
		return
	elseif keyCode == KEY.KeypadThree then
		rotAxis = "Z"
		updateDisplay()
		return
	end

	-- Get current step
	local step = STEPS[stepIndex]

	-- Get references to current pos/rot
	local pos, rot
	if mode == "HIP" then
		pos, rot = hipPos, hipRot
	elseif mode == "ADS" then
		pos, rot = adsPos, adsRot
	elseif mode == "AXIS" then
		-- Axis only has rotation
		rot = axisRot
	end

	-- Numpad 0: Reset current mode
	if keyCode == KEY.KeypadZero then
		if mode == "HIP" then
			hipPos = Vector3.new(0.30, -0.36, -0.50)
			hipRot = Vector3.new(0, 0, 0)
		elseif mode == "ADS" then
			adsPos = Vector3.new(-0.299, -0.35, -0.55)
			adsRot = Vector3.new(0, 0, 0)
		elseif mode == "AXIS" then
			axisRot = Vector3.new(0, 0, 0)
		end
		updateDisplay()
		apply()
		return
	end

	-- POSITION: Numpad 8/5/4/6/9/7
	if mode ~= "AXIS" and pos then
		if keyCode == KEY.KeypadEight then
			-- Forward (-Z)
			if mode == "HIP" then hipPos = hipPos + Vector3.new(0, 0, -step.pos)
			else adsPos = adsPos + Vector3.new(0, 0, -step.pos) end
		elseif keyCode == KEY.KeypadFive then
			-- Backward (+Z)
			if mode == "HIP" then hipPos = hipPos + Vector3.new(0, 0, step.pos)
			else adsPos = adsPos + Vector3.new(0, 0, step.pos) end
		elseif keyCode == KEY.KeypadFour then
			-- Left (-X)
			if mode == "HIP" then hipPos = hipPos + Vector3.new(-step.pos, 0, 0)
			else adsPos = adsPos + Vector3.new(-step.pos, 0, 0) end
		elseif keyCode == KEY.KeypadSix then
			-- Right (+X)
			if mode == "HIP" then hipPos = hipPos + Vector3.new(step.pos, 0, 0)
			else adsPos = adsPos + Vector3.new(step.pos, 0, 0) end
		elseif keyCode == KEY.KeypadNine then
			-- Up (+Y)
			if mode == "HIP" then hipPos = hipPos + Vector3.new(0, step.pos, 0)
			else adsPos = adsPos + Vector3.new(0, step.pos, 0) end
		elseif keyCode == KEY.KeypadSeven then
			-- Down (-Y)
			if mode == "HIP" then hipPos = hipPos + Vector3.new(0, -step.pos, 0)
			else adsPos = adsPos + Vector3.new(0, -step.pos, 0) end
		end
	end

	-- ROTATION: Numpad + / -
	if rot then
		local rotDelta = Vector3.new(
			rotAxis == "X" and step.rot or 0,
			rotAxis == "Y" and step.rot or 0,
			rotAxis == "Z" and step.rot or 0
		)

		if keyCode == KEY.KeypadPlus then
			if mode == "HIP" then hipRot = hipRot + rotDelta
			elseif mode == "ADS" then adsRot = adsRot + rotDelta
			elseif mode == "AXIS" then axisRot = axisRot + rotDelta end
		elseif keyCode == KEY.KeypadMinus then
			if mode == "HIP" then hipRot = hipRot - rotDelta
			elseif mode == "ADS" then adsRot = adsRot - rotDelta
			elseif mode == "AXIS" then axisRot = axisRot - rotDelta end
		end
	end

	updateDisplay()
	apply()
end)

print("[ADSTuner] Loaded. Press T to toggle.")