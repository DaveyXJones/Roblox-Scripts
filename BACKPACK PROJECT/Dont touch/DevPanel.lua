--==================================================
-- DevPanel
-- LocalScript ? StarterPlayerScripts
--
-- DEV TOOL: Small draggable GUI panel with buttons
-- to force-equip any weapon from WeaponConfig,
-- toggle god mode, and toggle infinite ammo.
--
-- Bypasses the loot/equipment system by injecting
-- a fake item into EquipmentModule via DevSetSlot().
--
-- REQUIRES: Add this function to EquipmentModule:
--
--   function EquipmentModule.DevSetSlot(slotName, item)
--       slots[slotName] = item
--       print("[Equipment] DEV: Set " .. slotName
--           .. " = " .. (item and item.name or "nil"))
--   end
--
-- REMOVE THIS SCRIPT BEFORE SHIPPING.
--==================================================
local DEV_MODE = true  -- set to false to disable DevPanel
if not DEV_MODE then return end

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local GuiService        = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PANEL_WIDTH = 196
local TITLE_HEIGHT = 28
local PANEL_MARGIN = 10
local PANEL_MAX_HEIGHT = 520

-- ============================================================
-- WAIT FOR MODULES TO LOAD
-- ============================================================
task.wait(3)

-- ============================================================
-- MODULE FINDER
-- Searches PlayerScripts tree for a ModuleScript by name
-- ============================================================
local playerScripts = player:WaitForChild("PlayerScripts")

local moduleCache = {}

local function findModule(name)
	if moduleCache[name] then return moduleCache[name] end

	-- Search all descendants of PlayerScripts
	for _, desc in ipairs(playerScripts:GetDescendants()) do
		if desc:IsA("ModuleScript") and desc.Name == name then
			local ok, result = pcall(require, desc)
			if ok then
				moduleCache[name] = result
				return result
			else
				warn("[DevPanel] Failed to require " .. name .. ": " .. tostring(result))
			end
		end
	end

	-- Also check ReplicatedStorage (for WeaponConfig, etc.)
	for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
		if desc:IsA("ModuleScript") and desc.Name == name then
			local ok, result = pcall(require, desc)
			if ok then
				moduleCache[name] = result
				return result
			end
		end
	end

	return nil
end

-- ============================================================
-- LOAD WEAPON CONFIG
-- ============================================================
local WeaponConfig = findModule("WeaponConfig")
if not WeaponConfig then
	warn("[DevPanel] Could not find WeaponConfig — panel disabled")
	return
end

-- ============================================================
-- BUILD THE GUI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name                 = "DevPanel"
screenGui.ResetOnSpawn         = false
screenGui.DisplayOrder         = 999
screenGui.ZIndexBehavior       = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset       = false
screenGui.Parent               = playerGui

-- -- Main frame --
local frame = Instance.new("Frame")
frame.Name              = "Panel"
frame.Size              = UDim2.new(0, PANEL_WIDTH, 0, 0) -- height set dynamically
frame.Position          = UDim2.new(0, PANEL_MARGIN, 0, 84)
frame.BackgroundColor3  = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel   = 0
frame.Parent            = screenGui

local corner = Instance.new("UICorner", frame)
corner.CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke", frame)
stroke.Color       = Color3.fromRGB(255, 80, 80)
stroke.Thickness   = 1.5
stroke.Transparency = 0.3

-- -- Title bar (also the drag handle) --
local titleBar = Instance.new("Frame")
titleBar.Name              = "TitleBar"
titleBar.Size              = UDim2.new(1, 0, 0, TITLE_HEIGHT)
titleBar.BackgroundColor3  = Color3.fromRGB(180, 40, 40)
titleBar.BackgroundTransparency = 0.1
titleBar.BorderSizePixel   = 0
titleBar.Parent            = frame

local titleCorner = Instance.new("UICorner", titleBar)
titleCorner.CornerRadius = UDim.new(0, 8)

-- Square off the bottom corners of the title bar
local titleFix = Instance.new("Frame")
titleFix.Size              = UDim2.new(1, 0, 0, 10)
titleFix.Position          = UDim2.new(0, 0, 1, -10)
titleFix.BackgroundColor3  = Color3.fromRGB(180, 40, 40)
titleFix.BackgroundTransparency = 0.1
titleFix.BorderSizePixel   = 0
titleFix.Parent            = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Name              = "Title"
titleLabel.Size              = UDim2.new(1, -8, 1, 0)
titleLabel.Position          = UDim2.new(0, 8, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text              = "DEV PANEL"
titleLabel.TextColor3        = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize          = 13
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.TextXAlignment    = Enum.TextXAlignment.Left
titleLabel.Parent            = titleBar

-- -- Toggle button (top-right of title bar) --
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name              = "Toggle"
toggleBtn.Size              = UDim2.new(0, 24, 0, 24)
toggleBtn.Position          = UDim2.new(1, -28, 0, 2)
toggleBtn.BackgroundColor3  = Color3.fromRGB(120, 30, 30)
toggleBtn.BorderSizePixel   = 0
toggleBtn.Text              = "—"
toggleBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
toggleBtn.TextSize          = 14
toggleBtn.Font              = Enum.Font.GothamBold
toggleBtn.Parent            = titleBar

local toggleCorner = Instance.new("UICorner", toggleBtn)
toggleCorner.CornerRadius = UDim.new(0, 4)

-- -- Content container (holds all buttons) --
local content = Instance.new("ScrollingFrame")
content.Name              = "Content"
content.Size              = UDim2.new(1, -12, 1, -34)
content.Position          = UDim2.new(0, 6, 0, 31)
content.BackgroundTransparency = 1
content.BorderSizePixel   = 0
content.CanvasSize        = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.None
content.ScrollBarThickness = 6
content.ScrollBarImageColor3 = Color3.fromRGB(190, 70, 70)
content.ScrollBarImageTransparency = 0.2
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
content.Parent            = frame

local listLayout = Instance.new("UIListLayout", content)
listLayout.Padding         = UDim.new(0, 4)
listLayout.SortOrder       = Enum.SortOrder.LayoutOrder
listLayout.FillDirection   = Enum.FillDirection.Vertical

local function getViewportSize()
	local inset = GuiService:GetGuiInset()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	return Vector2.new(
		math.max(0, viewport.X - inset.X),
		math.max(0, viewport.Y - inset.Y)
	)
end

local function clampPanelPosition()
	local viewport = getViewportSize()
	local pos = frame.Position
	local x = math.clamp(pos.X.Offset, PANEL_MARGIN, math.max(PANEL_MARGIN, viewport.X - frame.AbsoluteSize.X - PANEL_MARGIN))
	local y = math.clamp(pos.Y.Offset, PANEL_MARGIN, math.max(PANEL_MARGIN, viewport.Y - frame.AbsoluteSize.Y - PANEL_MARGIN))
	frame.Position = UDim2.new(0, x, 0, y)
end

local collapsed = false

local function updateFrameSize()
	local contentHeight = listLayout.AbsoluteContentSize.Y
	content.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 8)

	if collapsed then
		content.Visible = false
		content.CanvasPosition = Vector2.new(0, 0)
		frame.Size = UDim2.new(0, PANEL_WIDTH, 0, TITLE_HEIGHT)
	else
		content.Visible = true
		local viewport = getViewportSize()
		local maxHeight = math.max(180, math.min(PANEL_MAX_HEIGHT, viewport.Y - (PANEL_MARGIN * 2)))
		local desiredHeight = TITLE_HEIGHT + contentHeight + 16
		frame.Size = UDim2.new(0, PANEL_WIDTH, 0, math.min(maxHeight, desiredHeight))
	end

	clampPanelPosition()
end

-- ============================================================
-- DRAGGING
-- ============================================================
local dragging    = false
local dragStart   = nil
local startPos    = nil

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging  = true
		dragStart = input.Position
		startPos  = frame.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
		clampPanelPosition()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

-- ============================================================
-- MINIMIZE / EXPAND
-- ============================================================
toggleBtn.MouseButton1Click:Connect(function()
	collapsed = not collapsed
	toggleBtn.Text = collapsed and "+" or "—"
	updateFrameSize()
end)

-- ============================================================
-- BUTTON FACTORY
-- ============================================================
local layoutOrder = 0

local function addSectionLabel(text)
	layoutOrder = layoutOrder + 1
	local label = Instance.new("TextLabel")
	label.Name              = "Section_" .. text
	label.Size              = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Text              = text
	label.TextColor3        = Color3.fromRGB(255, 120, 120)
	label.TextSize          = 11
	label.Font              = Enum.Font.GothamBold
	label.TextXAlignment    = Enum.TextXAlignment.Left
	label.LayoutOrder       = layoutOrder
	label.Parent            = content
end

local function addButton(label, callback)
	layoutOrder = layoutOrder + 1
	local btn = Instance.new("TextButton")
	btn.Name              = "Btn_" .. label
	btn.Size              = UDim2.new(1, 0, 0, 26)
	btn.BackgroundColor3  = Color3.fromRGB(45, 45, 45)
	btn.BorderSizePixel   = 0
	btn.Text              = label
	btn.TextColor3        = Color3.fromRGB(220, 220, 220)
	btn.TextSize          = 12
	btn.Font              = Enum.Font.GothamMedium
	btn.LayoutOrder       = layoutOrder
	btn.Parent            = content

	local btnCorner = Instance.new("UICorner", btn)
	btnCorner.CornerRadius = UDim.new(0, 4)

	-- Hover effect
	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	end)

	btn.MouseButton1Click:Connect(function()
		-- Flash feedback
		btn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
		task.delay(0.15, function()
			btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		end)
		callback()
	end)

	return btn
end

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateFrameSize)
task.defer(updateFrameSize)
task.defer(clampPanelPosition)
local camera = workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateFrameSize)
end

-- ============================================================
-- EQUIP WEAPON FUNCTION
-- ============================================================
local function equipWeapon(assetName)
	local Equipment    = findModule("EquipmentModule")
	local Weapon       = findModule("WeaponModule")
	local ItemRegistry = findModule("ItemRegistry")

	if not Equipment then warn("[DevPanel] Could not find EquipmentModule"); return end
	if not Weapon    then warn("[DevPanel] Could not find WeaponModule");    return end

	local cfg = WeaponConfig.Get(assetName)
	if not cfg then warn("[DevPanel] No config for: " .. assetName); return end

	-- Determine which equipment slot this goes in
	local slotName = "primary"
	local nameLower = assetName:lower()
	if nameLower:find("p226") or nameLower:find("deagle") then
		slotName = "secondary"
	elseif nameLower:find("frag") or nameLower:find("smoke") or nameLower:find("flash") or nameLower:find("molotov") or nameLower:find("grenade") then
		slotName = "grenade"
	elseif nameLower:find("knife") or nameLower:find("axe") or nameLower:find("melee") or nameLower:find("bat") or nameLower:find("machete") then
		slotName = "melee"
	end

	-- Try to find the real item from ItemRegistry by matching assetName
	local realItem = nil
	if ItemRegistry then
		local allLists = {
			ItemRegistry.WEAPONS_PRIMARY,
			ItemRegistry.WEAPONS_SECONDARY,
			ItemRegistry.WEAPONS_MELEE,
			ItemRegistry.WEAPONS_GRENADES,
		}
		for _, list in ipairs(allLists) do
			for _, entry in ipairs(list) do
				if entry.data and entry.data.assetName == assetName then
					realItem = ItemRegistry.Get(entry.id)
					break
				end
			end
			if realItem then break end
		end
	end

	local itemToEquip
	if realItem then
		-- Use the full ItemRegistry definition
		itemToEquip = realItem
		if Equipment.GetValidSlot then
			slotName = Equipment.GetValidSlot(realItem) or slotName
		elseif realItem.data and realItem.data.weaponSlot then
			slotName = realItem.data.weaponSlot
		end
		print("[DevPanel] Found ItemRegistry entry: " .. realItem.name)
	else
		-- Fallback: keep grenades grenade-shaped instead of turning them into fake rifles.
		warn("[DevPanel] No ItemRegistry match for asset: " .. assetName .. " - using fallback")
		if slotName == "grenade" then
			local grenadeType = "frag"
			if nameLower:find("smoke") then
				grenadeType = "smoke"
			elseif nameLower:find("flash") then
				grenadeType = "flashbang"
			elseif nameLower:find("molotov") then
				grenadeType = "molotov"
			end

			itemToEquip = {
				id = "dev_" .. grenadeType,
				name = assetName,
				type = "grenade",
				quantity = 1,
				maxStack = 1,
				data = {
					assetName = assetName,
					grenadeType = grenadeType,
					fuseTime = grenadeType == "frag" and 4 or (grenadeType == "smoke" and 1 or (grenadeType == "flashbang" and 2 or 0)),
					blastRadius = grenadeType == "frag" and 12 or (grenadeType == "molotov" and 8 or 10),
					damage = grenadeType == "frag" and 100 or (grenadeType == "molotov" and 15 or 0),
					throwDuration = grenadeType == "molotov" and 0.62 or 0.55,
					throwLabel = "THROWING",
					throwAnimationId = "rbxassetid://0",
					throwSoundId = "rbxassetid://0",
				},
			}
		else
			itemToEquip = {
				name = assetName,
				type = slotName,
				data = {
					assetName   = assetName,
					damage      = 25,
					maxAmmo     = 30,
					reloadTime  = 2.0,
					ammoType    = "5.56 Rounds",
					fireRate    = 0.10,
					fireModes   = { "Semi", "Auto" },
					defaultMode = 1,
				},
			}
		end
	end

	if Equipment.DevSetSlot then
		if slotName == "grenade" then
			Equipment.DevSetSlot("grenade", nil)
			Equipment.DevSetSlot("hands", itemToEquip)
		else
			Equipment.DevSetSlot(slotName, itemToEquip)
		end
	else
		warn("[DevPanel] EquipmentModule needs a DevSetSlot function!")
		return
	end

	Weapon.SetActiveSlot(slotName)
	print("[DevPanel] Equipped: " .. assetName .. " -> " .. (slotName == "grenade" and "hands" or slotName))
end

-- ============================================================
-- CLEAR HAND
-- ============================================================
local function clearHand()
	local Equipment = findModule("EquipmentModule")
	if Equipment and Equipment.DevSetSlot then
		Equipment.DevSetSlot("primary", nil)
		Equipment.DevSetSlot("secondary", nil)
		Equipment.DevSetSlot("grenade", nil)
		Equipment.DevSetSlot("hands", nil)
	end
	local weaponEquippedEvent = ReplicatedStorage:FindFirstChild("WeaponEquipped")
	if weaponEquippedEvent then
		weaponEquippedEvent:FireServer("")
	end
	print("[DevPanel] Cleared hand")
end

-- ============================================================
-- POPULATE BUTTONS
-- ============================================================

-- -- Weapon buttons (sorted by name) --
addSectionLabel("WEAPONS")

local sortedNames = {}
for name, _ in pairs(WeaponConfig.CONFIGS) do
	table.insert(sortedNames, name)
end
table.sort(sortedNames)

for _, name in ipairs(sortedNames) do
	addButton(name, function()
		equipWeapon(name)
	end)
end

addButton("Clear Hand", clearHand)

-- -- Utility buttons --
addSectionLabel("UTILITIES")

local godActive = false
addButton("God Mode", function()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	godActive = not godActive
	if godActive then
		hum.MaxHealth = 999999
		hum.Health    = 999999
		print("[DevPanel] God mode ON")
	else
		hum.MaxHealth = 100
		hum.Health    = 100
		print("[DevPanel] God mode OFF")
	end
end)

local ammoActive = false
addButton("Infinite Ammo", function()
	local Weapon = findModule("WeaponModule")
	if not Weapon then return end

	ammoActive = not ammoActive
	Weapon.SetInfiniteAmmo(ammoActive)
	print("[DevPanel] Infinite ammo: " .. tostring(ammoActive))
end)
----------------------------------------------------------
------Attachments Addon-------------------------Thanks Claude!
-- ============================================================
-- ATTACHMENTS SECTION
-- ============================================================
addSectionLabel("ATTACHMENTS")

local function giveAttachment(attachId)
	local Inventory    = findModule("InventoryModule")
	local ItemRegistry = findModule("ItemRegistry")

	if not Inventory or not ItemRegistry then
		warn("[DevPanel] Missing module for attachments")
		return
	end

	local attachItem = ItemRegistry.Get(attachId)
	if not attachItem then
		warn("[DevPanel] No ItemRegistry entry for: " .. attachId)
		return
	end

	local added = Inventory.AddItem(attachItem)
	if not added then
		warn("[DevPanel] Bag full - could not add " .. attachItem.name)
		return
	end

	print("[DevPanel] Added attachment to bag: " .. attachItem.name)
end

local function clearAttachments()
	local Equipment = findModule("EquipmentModule")
	local Weapon    = findModule("WeaponModule")
	local AttachMod = findModule("AttachmentModule")

	if not Equipment or not Weapon or not AttachMod then return end

	local slotName = Weapon.GetActiveSlotName()
	local weapon   = Equipment.GetSlot("hands") or Equipment.GetSlot(slotName)
	if not weapon then return end

	for _, aType in ipairs({"scope", "suppressor", "grip"}) do
		local removed = AttachMod.Detach(weapon, aType)
		if removed then
			print("[DevPanel] Detached: " .. removed.name)
		end
	end
	Weapon.SetActiveSlot(slotName)
	print("[DevPanel] Cleared all attachments from " .. weapon.name)
end

-- Build buttons from ItemRegistry.ATTACHMENTS
local ItemRegistry = findModule("ItemRegistry")
if ItemRegistry and ItemRegistry.ATTACHMENTS then
	local sortedAttach = {}
	for _, entry in ipairs(ItemRegistry.ATTACHMENTS) do
		table.insert(sortedAttach, entry)
	end
	table.sort(sortedAttach, function(a, b) return a.name < b.name end)

	for _, entry in ipairs(sortedAttach) do
		addButton(entry.name, function()
			giveAttachment(entry.id)
		end)
	end
end

addButton("Clear Attachments", clearAttachments)

-- ============================================================
-- SET FINAL FRAME HEIGHT
-- ============================================================
task.defer(function()
	updateFrameSize()
end)

print("[DevPanel] Ready. " .. #sortedNames .. " weapons loaded.")
