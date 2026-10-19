--==================================================
-- BackpackUI
-- DayZ-style inventory screen for Roblox.
--==================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BackpackUI = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local Inventory = nil
local Equipment = nil
local Attachment = nil
local CameraModule = nil
local HUD = nil

local lootRemotes = ReplicatedStorage:WaitForChild("LootRemotes", 10)
local RE_DropItem = lootRemotes and lootRemotes:WaitForChild("DropItem", 5)
local RF_GetVicinityLoot = lootRemotes and lootRemotes:WaitForChild("GetVicinityLoot", 5)
local RF_TakeVicinityLoot = lootRemotes and lootRemotes:WaitForChild("TakeVicinityLoot", 5)
local RF_GetDeathBagVicinity = lootRemotes and lootRemotes:WaitForChild("GetDeathBagVicinity", 5)
local RF_TakeDeathBagItem = lootRemotes and lootRemotes:WaitForChild("TakeDeathBagItem", 5)

local C = {
	BG = Color3.fromRGB(9, 12, 16),
	PANEL = Color3.fromRGB(15, 19, 24),
	PANEL_ALT = Color3.fromRGB(20, 25, 31),
	SLOT = Color3.fromRGB(24, 30, 37),
	SLOT_HOVER = Color3.fromRGB(31, 39, 48),
	SLOT_ACTIVE = Color3.fromRGB(42, 54, 67),
	BORDER = Color3.fromRGB(48, 59, 71),
	BORDER_DIM = Color3.fromRGB(35, 43, 52),
	TEXT = Color3.fromRGB(212, 219, 224),
	TEXT_DIM = Color3.fromRGB(124, 136, 146),
	TEXT_MUTE = Color3.fromRGB(88, 98, 106),
	ACCENT = Color3.fromRGB(119, 148, 170),
	ACCENT_WARM = Color3.fromRGB(183, 149, 93),
}

local WINDOW_W = 1340
local WINDOW_H = 780
local BAG_CELL = 40
local BAG_PAD = 4
local BAG_GRID_W = 12
local BAG_GRID_H = 10
local WINDOW_SAFE_PAD = 20
local WINDOW_ALPHA = 0.2
local PANEL_ALPHA = 0.28
local PANEL_ALT_ALPHA = 0.34
local SLOT_ALPHA = 0.4
local SLOT_HOVER_ALPHA = 0.28
local SLOT_ACTIVE_ALPHA = 0.18
local OVERLAY_ALPHA = 0.72
local CURSOR_OVERRIDE_STEP = "BackpackCursorOverride"

local isOpen = false
local refreshToken = 0
local selected = nil
local pendingDrag = nil
local dragState = nil
local previewModel = nil
local lastVicinitySignature = ""
local lastVicinityClickKey = nil
local lastVicinityClickAt = 0
local lastAttachmentClickKey = nil
local lastAttachmentClickAt = 0
local bagItemFrames = {}
local equipSlotFrames = {}
local vicinityWidgets = {}
local currentVicinityLookup = {}
local vicinityCardRefs = {}
local hoveredVicinityKey = nil

local refreshBag
local refreshEquipment
local refreshVicinity
local refreshPreview
local refreshStatus
local rebuildPouches
local makeVicinitySignature
local dropSelectedItem
local close
local customCursor
local cursorGui
local cursorRenderConn
local cursorInputConn
local viewportConn
local currentPointerPosition = Vector2.new(0, 0)

local function cloneTable(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = type(v) == "table" and cloneTable(v) or v
	end
	return copy
end

local function notify(text, duration)
	if HUD and HUD.ShowNotif then
		HUD.ShowNotif(text, duration or 1.5)
	end
end

local function forceCursorMode(active)
	if active then
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
		GuiService.AutoSelectGuiEnabled = false
		GuiService.SelectedObject = nil
	else
		UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		UIS.MouseIconEnabled = false
		GuiService.SelectedObject = nil
	end
end

local function updateCursorPosition(position)
	if not customCursor then return end
	local x
	local y
	if position then
		x = position.X
		y = position.Y
	else
		local pos = UIS:GetMouseLocation()
		x = pos.X
		y = pos.Y
	end
	if mouse and mouse.X and mouse.Y then
		if mouse.X > 0 then x = mouse.X end
		if mouse.Y > 0 then y = mouse.Y end
	end
	customCursor.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
	customCursor.Visible = isOpen and (not UIS.TouchEnabled or UIS.MouseEnabled)
	currentPointerPosition = Vector2.new(x, y)
end

local function getInputPoint(input)
	if input and input.Position then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	local pos = UIS:GetMouseLocation()
	return Vector2.new(pos.X, pos.Y)
end

local function getPointerPoint()
	if currentPointerPosition.X ~= 0 or currentPointerPosition.Y ~= 0 then
		return currentPointerPosition
	end
	return getInputPoint(nil)
end

local function isDragPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function bindCursorOverride()
	if cursorRenderConn then
		cursorRenderConn:Disconnect()
		cursorRenderConn = nil
	end
	if cursorInputConn then
		cursorInputConn:Disconnect()
		cursorInputConn = nil
	end
	cursorRenderConn = RunService.RenderStepped:Connect(function()
		if not isOpen then return end
		forceCursorMode(true)
	end)
	cursorInputConn = UIS.InputChanged:Connect(function(input)
		if not isOpen then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			currentPointerPosition = getInputPoint(input)
		end
	end)
	customCursor.Visible = false
end

local function unbindCursorOverride()
	if cursorRenderConn then
		cursorRenderConn:Disconnect()
		cursorRenderConn = nil
	end
	if cursorInputConn then
		cursorInputConn:Disconnect()
		cursorInputConn = nil
	end
	customCursor.Visible = false
end

local function makeInventoryItem(item)
	if not item then return nil end
	return {
		id = item.id or "",
		name = item.name,
		type = item.type or "",
		quantity = item.quantity or 1,
		maxStack = item.maxStack or 1,
		iconId = item.iconId or "",
		data = cloneTable(item.data or {}),
		gridW = item.gridW,
		gridH = item.gridH,
	}
end

local function makeEquipmentItem(item)
	if not item then return nil end
	return {
		id = item.id or "",
		name = item.name,
		type = item.type or "",
		quantity = 1,
		maxStack = 1,
		iconId = item.iconId or "",
		data = cloneTable(item.data or {}),
	}
end

local function isAttachmentItem(item)
	if not item or not item.data then return false end
	local attachType = item.data.attachType
	return attachType == "scope" or attachType == "suppressor" or attachType == "grip"
end

local function isAttachmentWeapon(item)
	return item and (item.type == "primary" or item.type == "secondary")
end

local function makeAttachmentInventoryItem(attached)
	if not attached then return nil end
	return {
		id = attached.id or "",
		name = attached.name or "Attachment",
		type = attached.data and attached.data.attachType or "Misc",
		quantity = 1,
		maxStack = 1,
		iconId = attached.iconId or "",
		data = cloneTable(attached.data or {}),
	}
end

local function getAttachmentChipText(attached, attachType)
	if attached and attached.name and attached.name ~= "" then
		if attachType == "suppressor" then
			return "SUPP"
		elseif attachType == "scope" then
			return "SCOPE"
		elseif attachType == "grip" then
			return "GRIP"
		end
		return string.upper(attached.name)
	end
	if attachType == "suppressor" then
		return "SUPP"
	end
	return string.upper(attachType or "ATTACH")
end

local function canDropAttachmentOnSlot(targetSlot)
	if targetSlot == "primary" or targetSlot == "secondary" then
		return true
	end
	if targetSlot == "hands" and Equipment then
		return isAttachmentWeapon(Equipment.GetSlot("hands"))
	end
	return false
end

local function isMouseInside(guiObject, point)
	local pos = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

local function makePanelHeader(parent, title, subtitle)
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 52)
	header.BackgroundTransparency = 1
	header.Parent = parent

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -20, 0, 20)
	name.Position = UDim2.new(0, 14, 0, 8)
	name.BackgroundTransparency = 1
	name.Text = title
	name.TextColor3 = C.TEXT
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.Parent = header

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, -20, 0, 16)
	hint.Position = UDim2.new(0, 14, 0, 28)
	hint.BackgroundTransparency = 1
	hint.Text = subtitle
	hint.TextColor3 = C.TEXT_MUTE
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 10
	hint.Parent = header

	return header, name, hint
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BackpackUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 100
screenGui.Parent = player:WaitForChild("PlayerGui")

cursorGui = Instance.new("ScreenGui")
cursorGui.Name = "BackpackCursor"
cursorGui.ResetOnSpawn = false
cursorGui.IgnoreGuiInset = true
cursorGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
cursorGui.DisplayOrder = 1000
cursorGui.Enabled = false
cursorGui.Parent = screenGui.Parent

local overlay = Instance.new("Frame")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.ZIndex = 20
overlay.Parent = screenGui

local inputModal = Instance.new("TextButton")
inputModal.Name = "InputModal"
inputModal.Size = UDim2.new(1, 0, 1, 0)
inputModal.BackgroundTransparency = 1
inputModal.BorderSizePixel = 0
inputModal.Text = ""
inputModal.AutoButtonColor = false
inputModal.Active = true
inputModal.Modal = true
inputModal.Visible = false
inputModal.ZIndex = 20
inputModal.Parent = screenGui

customCursor = Instance.new("Frame")
customCursor.Name = "CustomCursor"
customCursor.Size = UDim2.new(0, 18, 0, 26)
customCursor.AnchorPoint = Vector2.new(0, 0)
customCursor.BackgroundTransparency = 1
customCursor.Visible = false
customCursor.ZIndex = 200
customCursor.Parent = cursorGui

local function makeCursorSegment(x, y, w, h, color, z, transparency)
	local seg = Instance.new("Frame")
	seg.Size = UDim2.new(0, w, 0, h)
	seg.Position = UDim2.new(0, x, 0, y)
	seg.BackgroundColor3 = color
	seg.BackgroundTransparency = transparency or 0
	seg.BorderSizePixel = 0
	seg.ZIndex = z
	seg.Parent = customCursor
	return seg
end

local cursorSegments = {
	{ 0, 0, 2, 2 },
	{ 0, 2, 2, 2 },
	{ 0, 4, 4, 2 },
	{ 0, 6, 4, 2 },
	{ 0, 8, 6, 2 },
	{ 0, 10, 6, 2 },
	{ 0, 12, 8, 2 },
	{ 0, 14, 8, 2 },
	{ 0, 16, 10, 2 },
	{ 2, 18, 4, 2 },
	{ 4, 20, 4, 2 },
	{ 6, 22, 4, 2 },
}

for _, segment in ipairs(cursorSegments) do
	makeCursorSegment(segment[1] + 1, segment[2] + 1, segment[3], segment[4], Color3.fromRGB(0, 0, 0), 200, 0.3)
end
for _, segment in ipairs(cursorSegments) do
	makeCursorSegment(segment[1], segment[2], segment[3], segment[4], Color3.fromRGB(245, 245, 245), 201, 0)
end

local window = Instance.new("Frame")
window.Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.new(0.5, 0, 1.45, 0)
window.BackgroundColor3 = C.BG
window.BackgroundTransparency = WINDOW_ALPHA
window.BorderSizePixel = 0
window.Visible = false
window.ZIndex = 21
window.Parent = screenGui
Instance.new("UICorner", window).CornerRadius = UDim.new(0, 14)
local winStroke = Instance.new("UIStroke", window)
winStroke.Color = C.BORDER
winStroke.Thickness = 1.5
local windowScale = Instance.new("UIScale")
windowScale.Scale = 1
windowScale.Parent = window

local function getViewportSize()
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.X > 0 and camera.ViewportSize.Y > 0 then
		return camera.ViewportSize
	end
	return Vector2.new(WINDOW_W, WINDOW_H)
end

local function updateWindowScale()
	local viewport = getViewportSize()
	local availableWidth = math.max(320, viewport.X - (WINDOW_SAFE_PAD * 2))
	local availableHeight = math.max(200, viewport.Y - (WINDOW_SAFE_PAD * 2))
	local scaleX = availableWidth / WINDOW_W
	local scaleY = availableHeight / WINDOW_H
	windowScale.Scale = math.clamp(math.min(scaleX, scaleY, 1), 0.35, 1)
end

local function bindViewportScaleUpdates()
	if viewportConn then
		viewportConn:Disconnect()
		viewportConn = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			updateWindowScale()
		end)
	end
end

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3 = C.PANEL
titleBar.BackgroundTransparency = PANEL_ALPHA
titleBar.BorderSizePixel = 0
titleBar.Parent = window
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 14)

local titleMask = Instance.new("Frame")
titleMask.Size = UDim2.new(1, 0, 0, 18)
titleMask.Position = UDim2.new(0, 0, 1, -18)
titleMask.BackgroundColor3 = C.PANEL
titleMask.BackgroundTransparency = PANEL_ALPHA
titleMask.BorderSizePixel = 0
titleMask.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 360, 1, 0)
title.Position = UDim2.new(0, 18, 0, 0)
title.BackgroundTransparency = 1
title.Text = "SURVIVOR LOADOUT"
title.TextColor3 = C.TEXT
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = titleBar

local subTitle = Instance.new("TextLabel")
subTitle.Size = UDim2.new(0, 520, 1, 0)
subTitle.Position = UDim2.new(0, 250, 0, 0)
subTitle.BackgroundTransparency = 1
subTitle.Text = "Drag nearby loot into the bag. Drag bag items into worn slots or hands."
subTitle.TextColor3 = C.TEXT_DIM
subTitle.TextXAlignment = Enum.TextXAlignment.Left
subTitle.Font = Enum.Font.Gotham
subTitle.TextSize = 11
subTitle.Parent = titleBar

local closeHint = Instance.new("TextLabel")
closeHint.Size = UDim2.new(0, 180, 1, 0)
closeHint.Position = UDim2.new(1, -196, 0, 0)
closeHint.BackgroundTransparency = 1
closeHint.Text = "TAB / ESC to close"
closeHint.TextColor3 = C.TEXT_MUTE
closeHint.TextXAlignment = Enum.TextXAlignment.Right
closeHint.Font = Enum.Font.GothamBold
closeHint.TextSize = 11
closeHint.Parent = titleBar

local mobileCloseButton = Instance.new("TextButton")
mobileCloseButton.Name = "MobileClose"
mobileCloseButton.Size = UDim2.new(0, 68, 0, 28)
mobileCloseButton.Position = UDim2.new(1, -86, 0.5, -14)
mobileCloseButton.BackgroundColor3 = C.SLOT
mobileCloseButton.BackgroundTransparency = 0.18
mobileCloseButton.BorderSizePixel = 0
mobileCloseButton.AutoButtonColor = false
mobileCloseButton.Text = "CLOSE"
mobileCloseButton.TextColor3 = C.TEXT
mobileCloseButton.Font = Enum.Font.GothamBold
mobileCloseButton.TextSize = 10
mobileCloseButton.Visible = UIS.TouchEnabled
mobileCloseButton.ZIndex = 23
mobileCloseButton.Parent = titleBar
Instance.new("UICorner", mobileCloseButton).CornerRadius = UDim.new(0, 8)
local mobileCloseStroke = Instance.new("UIStroke", mobileCloseButton)
mobileCloseStroke.Color = C.ACCENT_WARM
mobileCloseStroke.Thickness = 1

if UIS.TouchEnabled then
	closeHint.Visible = false
end

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -20, 1, -64)
body.Position = UDim2.new(0, 10, 0, 54)
body.BackgroundTransparency = 1
body.Parent = window

local function makePanel(parent, size, pos)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = pos
	frame.BackgroundColor3 = C.PANEL
	frame.BackgroundTransparency = PANEL_ALPHA
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = C.BORDER_DIM
	stroke.Thickness = 1
	return frame
end

local vicinityPanel = makePanel(body, UDim2.new(0, 320, 1, 0), UDim2.new(0, 0, 0, 0))
local centerPanel = makePanel(body, UDim2.new(0, 410, 1, 0), UDim2.new(0, 336, 0, 0))
local bagPanel = makePanel(body, UDim2.new(1, -762, 1, 0), UDim2.new(0, 762, 0, 0))

local _, vicinityTitle = makePanelHeader(vicinityPanel, "VICINITY", "Nearby loot, dropped items, and death bags")
makePanelHeader(centerPanel, "LOADOUT", "Character, weapons, clothing, and gear")
local _, bagTitle, bagHint = makePanelHeader(bagPanel, "BAG", "Grid storage")

local vicinityScroll = Instance.new("ScrollingFrame")
vicinityScroll.Size = UDim2.new(1, -16, 1, -62)
vicinityScroll.Position = UDim2.new(0, 8, 0, 54)
vicinityScroll.BackgroundTransparency = 1
vicinityScroll.BorderSizePixel = 0
vicinityScroll.ScrollBarThickness = 5
vicinityScroll.ScrollBarImageColor3 = C.BORDER
vicinityScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
vicinityScroll.Parent = vicinityPanel

local previewFrame = Instance.new("ViewportFrame")
previewFrame.Size = UDim2.new(0, 170, 0, 360)
previewFrame.Position = UDim2.new(0.5, -85, 0, 76)
previewFrame.BackgroundColor3 = C.PANEL_ALT
previewFrame.BackgroundTransparency = PANEL_ALT_ALPHA
previewFrame.BorderSizePixel = 0
previewFrame.ImageColor3 = Color3.fromRGB(235, 235, 235)
previewFrame.LightColor = Color3.fromRGB(255, 244, 224)
previewFrame.Ambient = Color3.fromRGB(120, 120, 120)
previewFrame.Parent = centerPanel
Instance.new("UICorner", previewFrame).CornerRadius = UDim.new(0, 12)
local previewStroke = Instance.new("UIStroke", previewFrame)
previewStroke.Color = C.BORDER
previewStroke.Thickness = 1

local previewCamera = Instance.new("Camera")
previewCamera.Parent = previewFrame
previewFrame.CurrentCamera = previewCamera

local slotLayout = {
	head = { x = 26, y = 86, w = 86, h = 58 },
	eyes = { x = 26, y = 154, w = 86, h = 58 },
	face = { x = 26, y = 222, w = 86, h = 58 },
	torso = { x = 26, y = 290, w = 86, h = 70 },
	vest = { x = 298, y = 86, w = 86, h = 70 },
	gloves = { x = 298, y = 166, w = 86, h = 58 },
	pants = { x = 298, y = 234, w = 86, h = 70 },
	boots = { x = 298, y = 314, w = 86, h = 58 },
	hands = { x = 135, y = 442, w = 140, h = 56 },
	primary = { x = 22, y = 510, w = 176, h = 68 },
	secondary = { x = 210, y = 510, w = 176, h = 68 },
	melee = { x = 22, y = 588, w = 114, h = 64 },
	grenade = { x = 146, y = 588, w = 114, h = 64 },
	utility = { x = 270, y = 588, w = 114, h = 64 },
}

local function buildSlot(parent, slotName, layout, accent)
	local supportsAttachmentBar = slotName == "primary" or slotName == "secondary" or slotName == "hands"
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, layout.w, 0, layout.h)
	frame.Position = UDim2.new(0, layout.x, 0, layout.y)
	frame.BackgroundColor3 = C.SLOT
	frame.BackgroundTransparency = SLOT_ALPHA
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = accent or C.BORDER
	stroke.Thickness = 1

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 0, 12)
	label.Position = UDim2.new(0, 6, 0, 4)
	label.BackgroundTransparency = 1
	label.Text = (Equipment and Equipment.SLOT_META and Equipment.SLOT_META[slotName] and Equipment.SLOT_META[slotName].label) or slotName:upper()
	label.TextColor3 = C.TEXT_MUTE
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.GothamBold
	label.TextSize = 9
	label.Parent = frame

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 28, 0, 28)
	icon.Position = UDim2.new(0, 8, 0, 20)
	icon.BackgroundTransparency = 1
	icon.Visible = false
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = frame

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -44, 0, supportsAttachmentBar and 16 or 30)
	name.Position = UDim2.new(0, 38, 0, 20)
	name.BackgroundTransparency = 1
	name.Text = ""
	name.TextWrapped = true
	name.TextColor3 = C.TEXT
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.Font = Enum.Font.GothamBold
	name.TextSize = 10
	name.Parent = frame

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = frame

	local attachmentButtons = nil
	if supportsAttachmentBar then
		attachmentButtons = {}
		local attachBar = Instance.new("Frame")
		attachBar.Name = "AttachmentBar"
		attachBar.Size = UDim2.new(1, -12, 0, 16)
		attachBar.Position = UDim2.new(0, 6, 1, -20)
		attachBar.BackgroundTransparency = 1
		attachBar.Parent = frame

		for i, attachType in ipairs({ "scope", "suppressor", "grip" }) do
			local chip = Instance.new("TextButton")
			chip.Name = "Attach_" .. attachType
			chip.Size = UDim2.new(0, 50, 1, 0)
			chip.Position = UDim2.new(0, (i - 1) * 54, 0, 0)
			chip.BackgroundColor3 = C.SLOT_HOVER
			chip.BackgroundTransparency = 0.12
			chip.BorderSizePixel = 0
			chip.AutoButtonColor = false
			chip.Text = ""
			chip.TextColor3 = C.TEXT
			chip.Font = Enum.Font.GothamBold
			chip.TextSize = 8
			chip.Visible = false
			chip.Parent = attachBar
			Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 6)
			local chipStroke = Instance.new("UIStroke", chip)
			chipStroke.Color = C.ACCENT_WARM
			chipStroke.Thickness = 1
			attachmentButtons[attachType] = chip
		end
	end

	equipSlotFrames[slotName] = {
		frame = frame,
		stroke = stroke,
		icon = icon,
		name = name,
		button = button,
		attachmentButtons = attachmentButtons,
		accent = accent or C.BORDER,
	}
end

for slotName, layout in pairs(slotLayout) do
	buildSlot(centerPanel, slotName, layout, (slotName == "vest" or slotName == "hands" or slotName == "utility") and C.ACCENT_WARM or C.ACCENT)
end

local pouchAnchor = Instance.new("Frame")
pouchAnchor.Size = UDim2.new(0, 362, 0, 64)
pouchAnchor.Position = UDim2.new(0, 22, 0, 652)
pouchAnchor.BackgroundTransparency = 1
pouchAnchor.Parent = centerPanel

local pouchHeader = Instance.new("TextLabel")
pouchHeader.Size = UDim2.new(1, 0, 0, 14)
pouchHeader.BackgroundTransparency = 1
pouchHeader.Text = "VEST POUCHES"
pouchHeader.TextColor3 = C.TEXT_MUTE
pouchHeader.TextXAlignment = Enum.TextXAlignment.Left
pouchHeader.Font = Enum.Font.GothamBold
pouchHeader.TextSize = 9
pouchHeader.Parent = pouchAnchor

local pouchContainer = Instance.new("Frame")
pouchContainer.Size = UDim2.new(1, 0, 1, -18)
pouchContainer.Position = UDim2.new(0, 0, 0, 18)
pouchContainer.BackgroundTransparency = 1
pouchContainer.Parent = pouchAnchor

local bagGridFrame = Instance.new("Frame")
bagGridFrame.Size = UDim2.new(0, BAG_GRID_W * BAG_CELL + (BAG_GRID_W - 1) * BAG_PAD + 16, 0, BAG_GRID_H * BAG_CELL + (BAG_GRID_H - 1) * BAG_PAD + 16)
bagGridFrame.Position = UDim2.new(0, 20, 0, 72)
bagGridFrame.BackgroundColor3 = C.PANEL_ALT
bagGridFrame.BackgroundTransparency = PANEL_ALT_ALPHA
bagGridFrame.BorderSizePixel = 0
bagGridFrame.Parent = bagPanel
Instance.new("UICorner", bagGridFrame).CornerRadius = UDim.new(0, 12)
local bagGridStroke = Instance.new("UIStroke", bagGridFrame)
bagGridStroke.Color = C.BORDER
bagGridStroke.Thickness = 1

local bagCellsLayer = Instance.new("Frame")
bagCellsLayer.Size = UDim2.new(1, -16, 1, -16)
bagCellsLayer.Position = UDim2.new(0, 8, 0, 8)
bagCellsLayer.BackgroundTransparency = 1
bagCellsLayer.Parent = bagGridFrame

local bagItemsLayer = Instance.new("Frame")
bagItemsLayer.Size = bagCellsLayer.Size
bagItemsLayer.Position = bagCellsLayer.Position
bagItemsLayer.BackgroundTransparency = 1
bagItemsLayer.Parent = bagGridFrame

for y = 1, BAG_GRID_H do
	for x = 1, BAG_GRID_W do
		local cell = Instance.new("Frame")
		cell.Size = UDim2.new(0, BAG_CELL, 0, BAG_CELL)
		cell.Position = UDim2.new(0, (x - 1) * (BAG_CELL + BAG_PAD), 0, (y - 1) * (BAG_CELL + BAG_PAD))
		cell.BackgroundColor3 = C.SLOT
		cell.BackgroundTransparency = SLOT_ALPHA
		cell.BorderSizePixel = 0
		cell.Parent = bagCellsLayer
		Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 7)
		local stroke = Instance.new("UIStroke", cell)
		stroke.Color = C.BORDER_DIM
		stroke.Thickness = 1
	end
end

local statusPanel = Instance.new("Frame")
statusPanel.Size = UDim2.new(1, -40, 0, 132)
statusPanel.Position = UDim2.new(0, 20, 1, -152)
statusPanel.BackgroundColor3 = C.PANEL_ALT
statusPanel.BackgroundTransparency = PANEL_ALT_ALPHA
statusPanel.BorderSizePixel = 0
statusPanel.Parent = bagPanel
Instance.new("UICorner", statusPanel).CornerRadius = UDim.new(0, 12)
local statusStroke = Instance.new("UIStroke", statusPanel)
statusStroke.Color = C.BORDER
statusStroke.Thickness = 1

local statusName = Instance.new("TextLabel")
statusName.Size = UDim2.new(1, -24, 0, 22)
statusName.Position = UDim2.new(0, 12, 0, 12)
statusName.BackgroundTransparency = 1
statusName.Text = "No item selected"
statusName.TextColor3 = C.TEXT
statusName.TextXAlignment = Enum.TextXAlignment.Left
statusName.Font = Enum.Font.GothamBold
statusName.TextSize = 14
statusName.Parent = statusPanel

local statusHint = Instance.new("TextLabel")
statusHint.Size = UDim2.new(1, -24, 0, 38)
statusHint.Position = UDim2.new(0, 12, 0, 38)
statusHint.BackgroundTransparency = 1
statusHint.TextWrapped = true
statusHint.TextYAlignment = Enum.TextYAlignment.Top
statusHint.Text = "Open the backpack near loot, then drag items into the bag grid. Drag bag items into worn slots or the hands slot."
statusHint.TextColor3 = C.TEXT_DIM
statusHint.TextXAlignment = Enum.TextXAlignment.Left
statusHint.Font = Enum.Font.Gotham
statusHint.TextSize = 11
statusHint.Parent = statusPanel

local actionRow = Instance.new("Frame")
actionRow.Size = UDim2.new(1, -24, 0, 22)
actionRow.Position = UDim2.new(0, 12, 0, 80)
actionRow.BackgroundTransparency = 1
actionRow.Visible = false
actionRow.Parent = statusPanel

local actionPrimary = Instance.new("TextButton")
actionPrimary.Size = UDim2.new(0, 150, 1, 0)
actionPrimary.Position = UDim2.new(0, 0, 0, 0)
actionPrimary.BackgroundColor3 = C.SLOT
actionPrimary.BackgroundTransparency = SLOT_ALPHA
actionPrimary.BorderSizePixel = 0
actionPrimary.AutoButtonColor = false
actionPrimary.Text = "QUICK MOVE"
actionPrimary.TextColor3 = C.TEXT
actionPrimary.Font = Enum.Font.GothamBold
actionPrimary.TextSize = 10
actionPrimary.Visible = false
actionPrimary.Parent = actionRow
Instance.new("UICorner", actionPrimary).CornerRadius = UDim.new(0, 7)
local actionPrimaryStroke = Instance.new("UIStroke", actionPrimary)
actionPrimaryStroke.Color = C.BORDER
actionPrimaryStroke.Thickness = 1

local actionDrop = Instance.new("TextButton")
actionDrop.Size = UDim2.new(0, 110, 1, 0)
actionDrop.Position = UDim2.new(0, 158, 0, 0)
actionDrop.BackgroundColor3 = Color3.fromRGB(52, 26, 26)
actionDrop.BackgroundTransparency = SLOT_ALPHA
actionDrop.BorderSizePixel = 0
actionDrop.AutoButtonColor = false
actionDrop.Text = "DROP"
actionDrop.TextColor3 = C.TEXT
actionDrop.Font = Enum.Font.GothamBold
actionDrop.TextSize = 10
actionDrop.Visible = false
actionDrop.Parent = actionRow
Instance.new("UICorner", actionDrop).CornerRadius = UDim.new(0, 7)
local actionDropStroke = Instance.new("UIStroke", actionDrop)
actionDropStroke.Color = Color3.fromRGB(132, 78, 78)
actionDropStroke.Thickness = 1

local detachRow = Instance.new("Frame")
detachRow.Size = UDim2.new(1, -24, 0, 24)
detachRow.Position = UDim2.new(0, 12, 1, -28)
detachRow.BackgroundTransparency = 1
detachRow.Visible = false
detachRow.Parent = statusPanel

local detachButtons = {}
for i, attachType in ipairs({ "scope", "suppressor", "grip" }) do
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 118, 1, 0)
	button.Position = UDim2.new(0, (i - 1) * 124, 0, 0)
	button.BackgroundColor3 = C.SLOT
	button.BackgroundTransparency = SLOT_ALPHA
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = "DETACH " .. attachType:upper()
	button.TextColor3 = C.TEXT
	button.Font = Enum.Font.GothamBold
	button.TextSize = 10
	button.Visible = false
	button.Parent = detachRow
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
	local stroke = Instance.new("UIStroke", button)
	stroke.Color = C.BORDER
	stroke.Thickness = 1
	detachButtons[attachType] = button
end

local dragGhost = Instance.new("Frame")
dragGhost.Size = UDim2.new(0, 170, 0, 42)
dragGhost.BackgroundColor3 = C.PANEL_ALT
dragGhost.BackgroundTransparency = 0.1
dragGhost.BorderSizePixel = 0
dragGhost.Visible = false
dragGhost.ZIndex = 40
dragGhost.Parent = screenGui
Instance.new("UICorner", dragGhost).CornerRadius = UDim.new(0, 8)
local dragGhostStroke = Instance.new("UIStroke", dragGhost)
dragGhostStroke.Color = C.ACCENT
dragGhostStroke.Thickness = 1.2

local dragGhostText = Instance.new("TextLabel")
dragGhostText.Size = UDim2.new(1, -12, 1, 0)
dragGhostText.Position = UDim2.new(0, 6, 0, 0)
dragGhostText.BackgroundTransparency = 1
dragGhostText.TextColor3 = C.TEXT
dragGhostText.TextXAlignment = Enum.TextXAlignment.Left
dragGhostText.Font = Enum.Font.GothamBold
dragGhostText.TextSize = 11
dragGhostText.Parent = dragGhost

local function clearSelection()
	selected = nil
	refreshBag()
	refreshEquipment()
	refreshVicinity()
	refreshStatus()
end

local function setSelected(sel)
	selected = sel
	refreshBag()
	refreshEquipment()
	refreshVicinity()
	refreshStatus()
end

local function getSelectedItem()
	if not selected then return nil end
	if selected.kind == "inventory" then
		return Inventory and Inventory.GetSlot(selected.slotIndex) or nil
	elseif selected.kind == "equipment" then
		return Equipment and Equipment.GetSlot(selected.slotName) or nil
	elseif selected.kind == "vicinity" then
		local entry = currentVicinityLookup[selected.key]
		return entry and entry.item or nil
	end
	return nil
end

local function updateSlotVisual(slotName, hovered)
	local info = equipSlotFrames[slotName]
	if not info then return end
	local active = selected and selected.kind == "equipment" and selected.slotName == slotName
	info.frame.BackgroundColor3 = active and C.SLOT_ACTIVE or (hovered and C.SLOT_HOVER or C.SLOT)
	info.frame.BackgroundTransparency = active and SLOT_ACTIVE_ALPHA or (hovered and SLOT_HOVER_ALPHA or SLOT_ALPHA)
	info.stroke.Color = active and C.ACCENT_WARM or (hovered and C.ACCENT or C.BORDER_DIM)
end

local function refreshPreviewModel()
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end

	local character = player.Character
	if not character then return end

	local wasArchivable = character.Archivable
	character.Archivable = true
	local ok, clone = pcall(function()
		return character:Clone()
	end)
	character.Archivable = wasArchivable
	if not ok or not clone then return end

	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("LocalScript") or descendant:IsA("Script") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end

	clone.Parent = previewFrame
	previewModel = clone
	clone:PivotTo(CFrame.new(0, -3, 0) * CFrame.Angles(0, math.rad(180), 0))
	previewCamera.CFrame = CFrame.new(Vector3.new(0, 0, 8), Vector3.new(0, -0.3, 0))
end

local function registerDraggable(button, buildPayload, onClick, hoverSlot)
	button.InputBegan:Connect(function(input)
		if not isOpen or not isDragPress(input) then return end
		pendingDrag = {
			input = input,
			start = getInputPoint(input),
			buildPayload = buildPayload,
			onClick = onClick,
		}
	end)

	if hoverSlot then
		button.MouseEnter:Connect(function() updateSlotVisual(hoverSlot, true) end)
		button.MouseLeave:Connect(function() updateSlotVisual(hoverSlot, false) end)
	end
end

local function normalizeInventoryDropCell(payload, rawX, rawY)
	if not payload or not rawX or not rawY or not Inventory then
		return rawX, rawY
	end

	local liveItem = Inventory.GetSlot and Inventory.GetSlot(payload.slotIndex) or nil
	local liveLayout = Inventory.GetItemLayout and Inventory.GetItemLayout(payload.slotIndex) or nil
	if not liveItem or not liveLayout then
		return rawX, rawY
	end

	local hoveredIndex, hoveredItem = Inventory.GetItemAtCell and Inventory.GetItemAtCell(rawX, rawY) or nil, nil
	if hoveredIndex then
		hoveredIndex, hoveredItem = Inventory.GetItemAtCell(rawX, rawY)
	end
	if hoveredIndex and hoveredIndex ~= payload.slotIndex then
		local hoveredLayout = Inventory.GetItemLayout and Inventory.GetItemLayout(hoveredIndex) or nil
		local sameSize = hoveredLayout
			and hoveredLayout.w == liveLayout.w
			and hoveredLayout.h == liveLayout.h
		local canStack = hoveredItem
			and hoveredItem.name == liveItem.name
			and (hoveredItem.maxStack or 1) > (hoveredItem.quantity or 0)
		if hoveredLayout and (sameSize or canStack) then
			return hoveredLayout.x, hoveredLayout.y
		end
	end

	local targetX = rawX - (payload.grabCellX or 0)
	local targetY = rawY - (payload.grabCellY or 0)
	local maxX = math.max(1, BAG_GRID_W - liveLayout.w + 1)
	local maxY = math.max(1, BAG_GRID_H - liveLayout.h + 1)
	return math.clamp(targetX, 1, maxX), math.clamp(targetY, 1, maxY)
end

local function bagCellFromMouse(point)
	if not isMouseInside(bagGridFrame, point) then return nil, nil end
	local localX = point.X - bagItemsLayer.AbsolutePosition.X
	local localY = point.Y - bagItemsLayer.AbsolutePosition.Y
	if localX < 0 or localY < 0 then return nil, nil end
	local pitch = BAG_CELL + BAG_PAD
	local x = math.floor(localX / pitch) + 1
	local y = math.floor(localY / pitch) + 1
	if x < 1 or x > BAG_GRID_W or y < 1 or y > BAG_GRID_H then return nil, nil end
	return x, y
end

local function equipmentSlotFromMouse(point)
	for slotName, info in pairs(equipSlotFrames) do
		if isMouseInside(info.frame, point) then
			return slotName
		end
	end
	return nil
end

local function inventoryHasRoomFor(item, preferredLayout)
	if not Inventory or not item then return false end
	for _, slot in ipairs(Inventory.GetAllSlots()) do
		if slot and slot.name == item.name and (slot.maxStack or 1) > (slot.quantity or 0) then
			return true
		end
	end
	if preferredLayout and Inventory.CanPlaceItemAt(item, preferredLayout.x, preferredLayout.y) then
		return true
	end
	local x = Inventory.FindOpenSpot(item)
	return x ~= nil
end

local function placeDisplacedItem(displaced, preferredLayout)
	if not displaced then return true end
	local stored = makeInventoryItem(displaced)
	local added = nil
	if preferredLayout then
		added = Inventory.AddItemAt(stored, preferredLayout.x, preferredLayout.y)
	end
	if not added then
		added = Inventory.AddItem(stored)
	end
	return added ~= nil
end

local function transferInventoryToEquipment(slotIndex, targetSlot)
	local item = Inventory and Inventory.GetSlot(slotIndex) or nil
	if not item or not Equipment then return false end

	if isAttachmentItem(item) and canDropAttachmentOnSlot(targetSlot) then
		local weapon = Equipment.GetSlot(targetSlot)
		if not weapon or not Attachment or not Attachment.CanAttach(weapon, item) then return false end
		local previous = Attachment.Detach(weapon, item.data.attachType)
		if previous then
			local returned = Inventory.AddItem(makeAttachmentInventoryItem(previous))
			if not returned then
				Attachment.Attach(weapon, makeAttachmentInventoryItem(previous))
				notify("Bag is full", 1.5)
				return false
			end
		end
		local ok = Attachment.Attach(weapon, item)
		if not ok then return false end
		Inventory.ClearSlot(slotIndex)
		notify("Attached " .. tostring(item.name) .. " to " .. tostring(weapon.name), 1.4)
		return true
	end

	if not Equipment.CanEquipInto(targetSlot, item) then return false end
	local existing = Equipment.GetSlot(targetSlot)
	local sourceLayout = Inventory.GetItemLayout(slotIndex)
	if existing and not inventoryHasRoomFor(makeEquipmentItem(existing), sourceLayout) then
		notify("No room for displaced item", 1.5)
		return false
	end

	local transfer = makeInventoryItem(item)
	Inventory.ClearSlot(slotIndex)
	local displaced = Equipment.Swap(targetSlot, transfer)
	if displaced and not placeDisplacedItem(displaced, sourceLayout) then
		Equipment.Swap(targetSlot, displaced)
		if sourceLayout then
			Inventory.AddItemAt(transfer, sourceLayout.x, sourceLayout.y)
		else
			Inventory.AddItem(transfer)
		end
		return false
	end
	return true
end

local function moveEquipmentToGrid(slotName, cellX, cellY)
	local item = Equipment and Equipment.GetSlot(slotName) or nil
	if not item or not Inventory then return false end
	local transfer = makeEquipmentItem(item)
	if not Inventory.CanPlaceItemAt(transfer, cellX, cellY) and not Inventory.GetItemAtCell(cellX, cellY) then
		return false
	end
	local occupiedIndex, occupiedItem = Inventory.GetItemAtCell(cellX, cellY)
	if occupiedItem and not (occupiedItem.name == transfer.name and (occupiedItem.maxStack or 1) > (occupiedItem.quantity or 0)) then
		return false
	end
	Equipment.Unequip(slotName)
	local added = Inventory.AddItemAt(transfer, cellX, cellY)
	if not added then
		Equipment.Equip(slotName, transfer)
		return false
	end
	return true
end

local function takeVicinityToGrid(key, cellX, cellY)
	local entry = currentVicinityLookup[key]
	if not entry or not Inventory then return false end
	local item = entry.item
	if not item then return false end
	local occupiedIndex, occupiedItem = Inventory.GetItemAtCell(cellX, cellY)
	if occupiedItem and not (occupiedItem.name == item.name and (occupiedItem.maxStack or 1) > (occupiedItem.quantity or 0)) then
		return false
	end
	if not occupiedItem and not Inventory.CanPlaceItemAt(item, cellX, cellY) then
		return false
	end

	local ok, success, serverItem = pcall(function()
		if entry.sourceType == "death_bag" and RF_TakeDeathBagItem then
			return RF_TakeDeathBagItem:InvokeServer(entry.sourceId, entry.itemIndex)
		end
		if RF_TakeVicinityLoot then
			return RF_TakeVicinityLoot:InvokeServer(entry.sourceId, entry.itemIndex)
		end
		return false, nil
	end)
	if not ok or success ~= true then return false end
	serverItem = serverItem or item
	local added = Inventory.AddItemAt(serverItem, cellX, cellY)
	if not added then
		added = Inventory.AddItem(serverItem)
	end
	if not added then
		notify("Bag is full", 1.5)
	end
	return added ~= nil
end

local function takeVicinityAuto(key)
	local entry = currentVicinityLookup[key]
	if not entry or not Inventory then return false end

	local item = entry.item
	if not item then return false end

	local ok, success, serverItem = pcall(function()
		if entry.sourceType == "death_bag" and RF_TakeDeathBagItem then
			return RF_TakeDeathBagItem:InvokeServer(entry.sourceId, entry.itemIndex)
		end
		if RF_TakeVicinityLoot then
			return RF_TakeVicinityLoot:InvokeServer(entry.sourceId, entry.itemIndex)
		end
		return false, nil
	end)
	if not ok or success ~= true then
		return false
	end

	serverItem = serverItem or item
	local added = Inventory.AddItem(serverItem)
	if not added then
		notify("Bag is full", 1.5)
		return false
	end

	refreshVicinity()
	return true
end

local function detachAttachment(attachType)
	if not selected or selected.kind ~= "equipment" then return end
	if not Attachment or not Inventory then return end
	local weapon = Equipment and Equipment.GetSlot(selected.slotName) or nil
	if not weapon then return end

	local removed = Attachment.Detach(weapon, attachType)
	if not removed then return end

	local added = Inventory.AddItem(makeAttachmentInventoryItem(removed))
	if not added then
		Attachment.Attach(weapon, makeAttachmentInventoryItem(removed))
		notify("Bag is full", 1.5)
		return
	end

	refreshBag()
	refreshEquipment()
	refreshStatus()
end

local function detachAttachmentToInventory(slotName, attachType, cellX, cellY)
	if not Attachment or not Inventory or not Equipment then return false end
	local weapon = Equipment.GetSlot(slotName)
	if not weapon then return false end

	local removed = Attachment.Detach(weapon, attachType)
	if not removed then return false end

	local item = makeAttachmentInventoryItem(removed)
	local added = nil
	if cellX and cellY then
		added = Inventory.AddItemAt(item, cellX, cellY)
		if not added then
			Attachment.Attach(weapon, item)
			notify("That bag space is blocked", 1.5)
			return false
		end
	else
		added = Inventory.AddItem(item)
		if not added then
			Attachment.Attach(weapon, item)
			notify("Bag is full", 1.5)
			return false
		end
	end

	refreshBag()
	refreshEquipment()
	refreshStatus()
	notify("Detached " .. tostring(item.name), 1.2)
	return true
end

local function beginDrag(payload)
	dragState = payload
	dragGhost.Visible = true
	dragGhostText.Text = payload.item.name
	local pos = getPointerPoint()
	dragGhost.Position = UDim2.new(0, pos.X + 12, 0, pos.Y + 12)
end

local function endDrag()
	dragState = nil
	dragGhost.Visible = false
end

local function finishDrag(point)
	if not dragState then return end
	local bagX, bagY = bagCellFromMouse(point)
	local targetSlot = equipmentSlotFromMouse(point)
	local handled = false

	if dragState.kind == "inventory" then
		if bagX and bagY then
			local dropX, dropY = normalizeInventoryDropCell(dragState, bagX, bagY)
			handled = Inventory.MoveItemToGrid(dragState.slotIndex, dropX, dropY)
		elseif targetSlot then
			handled = transferInventoryToEquipment(dragState.slotIndex, targetSlot)
		end
	elseif dragState.kind == "equipment" then
		if bagX and bagY then
			handled = moveEquipmentToGrid(dragState.slotName, bagX, bagY)
		elseif targetSlot and targetSlot ~= dragState.slotName then
			handled = Equipment.MoveSlot and Equipment.MoveSlot(dragState.slotName, targetSlot) or false
		end
	elseif dragState.kind == "equipped_attachment" then
		if bagX and bagY then
			handled = detachAttachmentToInventory(dragState.slotName, dragState.attachType, bagX, bagY)
		end
	elseif dragState.kind == "vicinity" then
		if bagX and bagY then
			handled = takeVicinityToGrid(dragState.key, bagX, bagY)
		end
	end

	endDrag()
	if handled then
		clearSelection()
		refreshVicinity()
	else
		refreshBag()
		refreshEquipment()
		refreshVicinity()
	end
end

local function quickMoveSelected()
	if not selected then return end

	if selected.kind == "inventory" then
		local item = Inventory and Inventory.GetSlot(selected.slotIndex) or nil
		if not item or not Equipment then return end
		local targetSlot = Equipment.GetValidSlot(item)
		if targetSlot and transferInventoryToEquipment(selected.slotIndex, targetSlot) then
			clearSelection()
		end
	elseif selected.kind == "equipment" then
		local item = Equipment and Equipment.GetSlot(selected.slotName) or nil
		if not item or not Inventory then return end
		if selected.slotName == "hands" then
			local holsterSlot = Equipment.GetValidSlot(item)
			if holsterSlot and holsterSlot ~= "hands" and Equipment.MoveSlot and Equipment.MoveSlot("hands", holsterSlot) then
				clearSelection()
				return
			end
			local transfer = makeEquipmentItem(item)
			local x, y = Inventory.FindOpenSpot(transfer)
			if x and y and moveEquipmentToGrid(selected.slotName, x, y) then
				clearSelection()
			else
				notify("Bag is full", 1.5)
			end
		else
			if Equipment.MoveSlot and Equipment.MoveSlot(selected.slotName, "hands") then
				clearSelection()
			else
				notify("Hands are busy", 1.5)
			end
		end
	end
end

dropSelectedItem = function()
	if not selected or not RE_DropItem then return end

	local item = nil
	if selected.kind == "inventory" then
		item = Inventory and Inventory.GetSlot(selected.slotIndex) or nil
	elseif selected.kind == "equipment" then
		item = Equipment and Equipment.GetSlot(selected.slotName) or nil
	else
		return
	end
	if not item then return end

	RE_DropItem:FireServer({
		id = item.id or "",
		name = item.name,
		type = item.type or "",
		quantity = item.quantity or 1,
		maxStack = item.maxStack or 1,
		iconId = item.iconId or "",
		data = cloneTable(item.data or {}),
	})

	if selected.kind == "inventory" then
		Inventory.ClearSlot(selected.slotIndex)
	else
		Equipment.Unequip(selected.slotName)
	end

	clearSelection()
	notify("Dropped " .. tostring(item.name), 1.2)
end

refreshStatus = function()
	actionRow.Visible = false
	actionPrimary.Visible = false
	actionDrop.Visible = false
	detachRow.Visible = false
	for _, button in pairs(detachButtons) do
		button.Visible = false
	end

	local item = getSelectedItem()
	if not item then
		statusName.Text = "No item selected"
		statusHint.Text = "Search containers first to reveal their contents in vicinity. Then drag items into the bag grid, worn slots, or hands."
		return
	end

	statusName.Text = item.name .. (((item.quantity or 1) > 1) and ("  x" .. tostring(item.quantity)) or "")
	if selected.kind == "inventory" then
		actionRow.Visible = true
		actionPrimary.Visible = true
		actionDrop.Visible = true
		actionPrimary.Text = "QUICK MOVE"
		if isAttachmentItem(item) then
			statusHint.Text = "Attachment item. Drag it onto a primary or secondary weapon slot, or onto the gun in your hands, to fit it."
		else
			statusHint.Text = "Drag it around the bag grid or drop it onto a compatible gear slot or hands. You can also quick move or drop it."
		end
	elseif selected.kind == "equipment" then
		actionRow.Visible = true
		actionPrimary.Visible = true
		actionDrop.Visible = true
		if selected.slotName == "hands" then
			actionPrimary.Text = "STOW ITEM"
			statusHint.Text = "Items in hands are the active / usable items. Drag this item to a carry slot or the bag, or use the quick actions below."
		else
			actionPrimary.Text = "MOVE TO HANDS"
			statusHint.Text = "This slot is a carry / holster slot. Move the item to hands before you can use it."
		end
		if (selected.slotName == "primary" or selected.slotName == "secondary" or (selected.slotName == "hands" and isAttachmentWeapon(item))) and item.data and item.data.attachments then
			detachRow.Visible = true
			for attachType, button in pairs(detachButtons) do
				button.Visible = item.data.attachments[attachType] ~= nil
			end
		end
	elseif selected.kind == "vicinity" then
		statusHint.Text = "Drag this nearby item into an open place in the bag grid to take it. Containers must be searched before their contents appear here."
	end
end

refreshEquipment = function()
	for slotName, info in pairs(equipSlotFrames) do
		local item = Equipment and Equipment.GetSlot(slotName) or nil
		if item then
			info.icon.Image = item.iconId or ""
			info.icon.Visible = (item.iconId or "") ~= ""
			info.name.Text = item.name or ""
		else
			info.icon.Image = ""
			info.icon.Visible = false
			info.name.Text = ""
		end
		if info.attachmentButtons then
			local attachments = item and item.data and item.data.attachments or nil
			for attachType, chip in pairs(info.attachmentButtons) do
				local attached = attachments and attachments[attachType] or nil
				chip.Visible = attached ~= nil
				chip.Text = attached and getAttachmentChipText(attached, attachType) or ""
			end
		end
		updateSlotVisual(slotName, false)
	end
	if Equipment then
		rebuildPouches()
		for _, slotName in ipairs(Equipment.GetPouchSlots()) do
			updateSlotVisual(slotName, false)
		end
	end
end

rebuildPouches = function()
	for slotName, info in pairs(equipSlotFrames) do
		if slotName:sub(1, 6) == "pouch_" then
			info.frame:Destroy()
			equipSlotFrames[slotName] = nil
		end
	end

	local pouchSlots = Equipment and Equipment.GetPouchSlots() or {}
	for i, slotName in ipairs(pouchSlots) do
		local layout = { x = (i - 1) * 60, y = 0, w = 56, h = 46 }
		buildSlot(pouchContainer, slotName, layout, C.ACCENT_WARM)
		local info = equipSlotFrames[slotName]
		registerDraggable(info.button, function()
			local item = Equipment and Equipment.GetSlot(slotName) or nil
			if not item then return nil end
			return { kind = "equipment", slotName = slotName, item = makeEquipmentItem(item) }
		end, function()
			setSelected({ kind = "equipment", slotName = slotName })
		end, slotName)
	end
end

local function clearBagFrames()
	for _, info in pairs(bagItemFrames) do
		info.frame:Destroy()
	end
	bagItemFrames = {}
end

refreshBag = function()
	clearBagFrames()
	if not Inventory then return end
	local gridW, gridH = Inventory.GetGridSize()
	bagTitle.Text = "BAG"
	bagHint.Text = gridW .. "x" .. gridH .. " grid"

	for i = 1, Inventory.GetSlotCount() do
		local item = Inventory.GetSlot(i)
		local layout = Inventory.GetItemLayout(i)
		if item and layout then
			local width = layout.w * BAG_CELL + (layout.w - 1) * BAG_PAD
			local height = layout.h * BAG_CELL + (layout.h - 1) * BAG_PAD
			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(0, width, 0, height)
			frame.Position = UDim2.new(0, (layout.x - 1) * (BAG_CELL + BAG_PAD), 0, (layout.y - 1) * (BAG_CELL + BAG_PAD))
			frame.BackgroundColor3 = C.SLOT_HOVER
			frame.BackgroundTransparency = SLOT_HOVER_ALPHA
			frame.BorderSizePixel = 0
			frame.Parent = bagItemsLayer
			Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 9)
			local stroke = Instance.new("UIStroke", frame)
			stroke.Color = C.BORDER
			stroke.Thickness = 1

			local icon = Instance.new("ImageLabel")
			icon.Size = UDim2.new(0, math.min(width - 12, 34), 0, math.min(height - 12, 34))
			icon.Position = UDim2.new(0, 6, 0, 6)
			icon.BackgroundTransparency = 1
			icon.ScaleType = Enum.ScaleType.Fit
			icon.Image = item.iconId or ""
			icon.Parent = frame

			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(1, -12, 0, 16)
			name.Position = UDim2.new(0, 6, 0, math.max(6, height - 24))
			name.BackgroundTransparency = 1
			name.Text = item.name or ""
			name.TextColor3 = C.TEXT
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.Font = Enum.Font.GothamBold
			name.TextSize = 10
			name.TextTruncate = Enum.TextTruncate.AtEnd
			name.Parent = frame

			local qty = Instance.new("TextLabel")
			qty.Size = UDim2.new(0, 32, 0, 14)
			qty.Position = UDim2.new(1, -38, 0, 6)
			qty.BackgroundTransparency = 1
			qty.Text = (item.quantity or 1) > 1 and ("x" .. tostring(item.quantity)) or ""
			qty.TextColor3 = C.TEXT_DIM
			qty.TextXAlignment = Enum.TextXAlignment.Right
			qty.Font = Enum.Font.GothamBold
			qty.TextSize = 9
			qty.Parent = frame

			if i <= 6 then
				local hotkey = Instance.new("TextLabel")
				hotkey.Size = UDim2.new(0, 18, 0, 12)
				hotkey.Position = UDim2.new(1, -24, 1, -18)
				hotkey.BackgroundTransparency = 1
				hotkey.Text = tostring(i + 2)
				hotkey.TextColor3 = C.ACCENT_WARM
				hotkey.Font = Enum.Font.GothamBold
				hotkey.TextSize = 8
				hotkey.Parent = frame
			end

			local button = Instance.new("TextButton")
			button.Size = UDim2.new(1, 0, 1, 0)
			button.BackgroundTransparency = 1
			button.Text = ""
			button.AutoButtonColor = false
			button.Parent = frame

			local active = selected and selected.kind == "inventory" and selected.slotIndex == i
			frame.BackgroundColor3 = active and C.SLOT_ACTIVE or C.SLOT_HOVER
			frame.BackgroundTransparency = active and SLOT_ACTIVE_ALPHA or SLOT_HOVER_ALPHA
			stroke.Color = active and C.ACCENT_WARM or C.BORDER

			registerDraggable(button, function(startPoint)
				local live = Inventory and Inventory.GetSlot(i) or nil
				local liveLayout = Inventory and Inventory.GetItemLayout and Inventory.GetItemLayout(i) or nil
				if not live then return nil end
				local grabCellX = 0
				local grabCellY = 0
				if startPoint and liveLayout then
					local pitch = BAG_CELL + BAG_PAD
					local localX = startPoint.X - frame.AbsolutePosition.X
					local localY = startPoint.Y - frame.AbsolutePosition.Y
					grabCellX = math.clamp(math.floor(localX / pitch), 0, math.max(0, liveLayout.w - 1))
					grabCellY = math.clamp(math.floor(localY / pitch), 0, math.max(0, liveLayout.h - 1))
				end
				return {
					kind = "inventory",
					slotIndex = i,
					item = makeInventoryItem(live),
					grabCellX = grabCellX,
					grabCellY = grabCellY,
				}
			end, function()
				setSelected({ kind = "inventory", slotIndex = i })
			end)

			button.MouseEnter:Connect(function()
				if not (selected and selected.kind == "inventory" and selected.slotIndex == i) then
					frame.BackgroundColor3 = C.SLOT_ACTIVE
					frame.BackgroundTransparency = SLOT_ACTIVE_ALPHA
					stroke.Color = C.ACCENT
				end
			end)
			button.MouseLeave:Connect(function()
				local on = selected and selected.kind == "inventory" and selected.slotIndex == i
				frame.BackgroundColor3 = on and C.SLOT_ACTIVE or C.SLOT_HOVER
				frame.BackgroundTransparency = on and SLOT_ACTIVE_ALPHA or SLOT_HOVER_ALPHA
				stroke.Color = on and C.ACCENT_WARM or C.BORDER
			end)

			bagItemFrames[i] = { frame = frame }
		end
	end
end

local function clearVicinityWidgets()
	for _, widget in ipairs(vicinityWidgets) do
		widget:Destroy()
	end
	vicinityWidgets = {}
	currentVicinityLookup = {}
	vicinityCardRefs = {}
	hoveredVicinityKey = nil
end

local function refreshVicinitySelectionVisuals()
	for key, refs in pairs(vicinityCardRefs) do
		local active = selected and selected.kind == "vicinity" and selected.key == key
		local hovered = hoveredVicinityKey == key
		refs.card.BackgroundColor3 = active and C.SLOT_ACTIVE or (hovered and C.SLOT_HOVER or C.SLOT)
		refs.card.BackgroundTransparency = active and SLOT_ACTIVE_ALPHA or (hovered and SLOT_HOVER_ALPHA or SLOT_ALPHA)
		refs.stroke.Color = active and C.ACCENT_WARM or (hovered and C.ACCENT or C.BORDER_DIM)
	end
end

refreshVicinity = function()
	if not isOpen then return end
	local entries = {}

	if RF_GetVicinityLoot then
		local ok, data = pcall(function() return RF_GetVicinityLoot:InvokeServer() end)
		if ok and type(data) == "table" then
			for _, entry in ipairs(data) do table.insert(entries, entry) end
		end
	end
	if RF_GetDeathBagVicinity then
		local ok, data = pcall(function() return RF_GetDeathBagVicinity:InvokeServer() end)
		if ok and type(data) == "table" then
			for _, entry in ipairs(data) do table.insert(entries, entry) end
		end
	end

	table.sort(entries, function(a, b)
		return (a.distance or math.huge) < (b.distance or math.huge)
	end)

	local signature = makeVicinitySignature(entries)
	if signature == lastVicinitySignature then
		vicinityTitle.Text = "VICINITY  (" .. tostring(#entries) .. ")"
		refreshVicinitySelectionVisuals()
		return
	end
	lastVicinitySignature = signature

	clearVicinityWidgets()

	local y = 0
	local selectedStillExists = false
	for _, entry in ipairs(entries) do
		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, -8, 0, 18)
		header.Position = UDim2.new(0, 4, 0, y)
		header.BackgroundTransparency = 1
		header.Text = string.upper(entry.label or "SOURCE") .. "   " .. string.format("%.1fm", entry.distance or 0)
		header.TextColor3 = C.TEXT_MUTE
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Font = Enum.Font.GothamBold
		header.TextSize = 10
		header.Parent = vicinityScroll
		table.insert(vicinityWidgets, header)
		y = y + 22

		for itemIndex, item in ipairs(entry.items or {}) do
			local key = tostring(entry.sourceType) .. "|" .. tostring(entry.sourceId) .. "|" .. tostring(itemIndex)
			currentVicinityLookup[key] = { sourceId = entry.sourceId, sourceType = entry.sourceType, itemIndex = itemIndex, item = item }
			if selected and selected.kind == "vicinity" and selected.key == key then selectedStillExists = true end

			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, -8, 0, 58)
			card.Position = UDim2.new(0, 4, 0, y)
			card.BackgroundColor3 = C.SLOT
			card.BackgroundTransparency = SLOT_ALPHA
			card.BorderSizePixel = 0
			card.Parent = vicinityScroll
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 9)
			local stroke = Instance.new("UIStroke", card)
			stroke.Color = C.BORDER_DIM
			stroke.Thickness = 1

			local icon = Instance.new("ImageLabel")
			icon.Size = UDim2.new(0, 36, 0, 36)
			icon.Position = UDim2.new(0, 10, 0, 11)
			icon.BackgroundTransparency = 1
			icon.ScaleType = Enum.ScaleType.Fit
			icon.Image = item.iconId or ""
			icon.Parent = card

			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(1, -86, 0, 18)
			name.Position = UDim2.new(0, 56, 0, 10)
			name.BackgroundTransparency = 1
			name.Text = item.name or ""
			name.TextColor3 = C.TEXT
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.Font = Enum.Font.GothamBold
			name.TextSize = 11
			name.Parent = card

			local meta = Instance.new("TextLabel")
			meta.Size = UDim2.new(1, -86, 0, 16)
			meta.Position = UDim2.new(0, 56, 0, 30)
			meta.BackgroundTransparency = 1
			meta.Text = tostring(item.type or "Item") .. (((item.quantity or 1) > 1) and ("  x" .. tostring(item.quantity)) or "")
			meta.TextColor3 = C.TEXT_MUTE
			meta.TextXAlignment = Enum.TextXAlignment.Left
			meta.Font = Enum.Font.Gotham
			meta.TextSize = 10
			meta.Parent = card

			local button = Instance.new("TextButton")
			button.Size = UDim2.new(1, 0, 1, 0)
			button.BackgroundTransparency = 1
			button.Text = ""
			button.AutoButtonColor = false
			button.Parent = card

			local active = selected and selected.kind == "vicinity" and selected.key == key
			local hovered = hoveredVicinityKey == key
			card.BackgroundColor3 = active and C.SLOT_ACTIVE or (hovered and C.SLOT_HOVER or C.SLOT)
			card.BackgroundTransparency = active and SLOT_ACTIVE_ALPHA or (hovered and SLOT_HOVER_ALPHA or SLOT_ALPHA)
			stroke.Color = active and C.ACCENT_WARM or (hovered and C.ACCENT or C.BORDER_DIM)
			vicinityCardRefs[key] = { card = card, stroke = stroke }

			registerDraggable(button, function()
				local live = currentVicinityLookup[key]
				if not live then return nil end
				return { kind = "vicinity", key = key, item = makeInventoryItem(live.item) }
			end, function()
				local now = tick()
				if lastVicinityClickKey == key and (now - lastVicinityClickAt) <= 0.45 then
					lastVicinityClickKey = nil
					lastVicinityClickAt = 0
					if takeVicinityAuto(key) then
						clearSelection()
					end
				else
					lastVicinityClickKey = key
					lastVicinityClickAt = now
					setSelected({ kind = "vicinity", key = key })
				end
			end)

			button.MouseEnter:Connect(function()
				hoveredVicinityKey = key
				refreshVicinitySelectionVisuals()
			end)
			button.MouseLeave:Connect(function()
				if hoveredVicinityKey == key then
					hoveredVicinityKey = nil
				end
				refreshVicinitySelectionVisuals()
			end)

			table.insert(vicinityWidgets, card)
			y = y + 66
		end
	end

	vicinityTitle.Text = "VICINITY  (" .. tostring(#entries) .. ")"
	vicinityScroll.CanvasSize = UDim2.new(0, 0, 0, y + 12)
	if selected and selected.kind == "vicinity" and not selectedStillExists then
		selected = nil
		refreshStatus()
	end
end

local function startRefreshLoop()
	refreshToken = refreshToken + 1
	local token = refreshToken
	task.spawn(function()
		while isOpen and token == refreshToken do
			refreshVicinity()
			task.wait(0.5)
		end
	end)
end

makeVicinitySignature = function(entries)
	local parts = {}
	for _, entry in ipairs(entries) do
		table.insert(parts, tostring(entry.sourceType) .. ":" .. tostring(entry.sourceId) .. ":" .. tostring(#(entry.items or {})))
		for itemIndex, item in ipairs(entry.items or {}) do
			table.insert(parts, tostring(itemIndex) .. ":" .. tostring(item.name) .. ":" .. tostring(item.quantity or 1))
		end
	end
	return table.concat(parts, "|")
end

UIS.InputChanged:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local point = getInputPoint(input)
	currentPointerPosition = point
	if pendingDrag and not dragState then
		local sameInput = false
		if pendingDrag.input.UserInputType == Enum.UserInputType.Touch then
			sameInput = input == pendingDrag.input
		elseif pendingDrag.input.UserInputType == Enum.UserInputType.MouseButton1 then
			sameInput = input.UserInputType == Enum.UserInputType.MouseMovement
		end
		if not sameInput then return end
		local delta = point - pendingDrag.start
		if delta.Magnitude >= 8 then
			local payload = pendingDrag.buildPayload(pendingDrag.start)
			if payload then beginDrag(payload) end
		end
	end
	if dragState then
		dragGhost.Position = UDim2.new(0, point.X + 12, 0, point.Y + 12)
	end
end)

UIS.InputEnded:Connect(function(input)
	if pendingDrag and input == pendingDrag.input then
		if dragState then
			finishDrag(getInputPoint(input))
		elseif pendingDrag.onClick then
			pendingDrag.onClick()
		end
		pendingDrag = nil
	end
end)

for attachType, button in pairs(detachButtons) do
	button.MouseButton1Click:Connect(function()
		detachAttachment(attachType)
	end)
end

actionPrimary.MouseButton1Click:Connect(function()
	quickMoveSelected()
end)

actionDrop.MouseButton1Click:Connect(function()
	dropSelectedItem()
end)

mobileCloseButton.MouseButton1Click:Connect(function()
	close()
end)

local tweenInfo = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local OPEN_POS = UDim2.new(0.5, 0, 0.5, 0)
local CLOSE_POS = UDim2.new(0.5, 0, 1.45, 0)

local function open()
	if isOpen then return end
	isOpen = true
	lastVicinitySignature = ""
	updateWindowScale()
	cursorGui.Enabled = true
	overlay.Visible = true
	inputModal.Visible = true
	customCursor.Visible = false
	window.Visible = true
	TweenService:Create(overlay, TweenInfo.new(0.18), { BackgroundTransparency = OVERLAY_ALPHA }):Play()
	TweenService:Create(window, tweenInfo, { Position = OPEN_POS }):Play()
	refreshPreviewModel()
	refreshBag()
	refreshEquipment()
	refreshVicinity()
	refreshStatus()
	startRefreshLoop()
	if CameraModule and CameraModule.SetUIOverride then CameraModule.SetUIOverride(true) end
	forceCursorMode(true)
	bindCursorOverride()
	task.defer(function()
		if isOpen then
			forceCursorMode(true)
		end
	end)
end

close = function()
	if not isOpen then return end
	isOpen = false
	refreshToken = refreshToken + 1
	lastVicinitySignature = ""
	lastVicinityClickKey = nil
	lastVicinityClickAt = 0
	inputModal.Visible = false
	customCursor.Visible = false
	cursorGui.Enabled = false
	pendingDrag = nil
	endDrag()
	unbindCursorOverride()
	clearSelection()
	TweenService:Create(overlay, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
	local tween = TweenService:Create(window, tweenInfo, { Position = CLOSE_POS })
	tween:Play()
	tween.Completed:Connect(function()
		if not isOpen then
			overlay.Visible = false
			window.Visible = false
		end
	end)
	if CameraModule and CameraModule.SetUIOverride then CameraModule.SetUIOverride(false) end
	forceCursorMode(false)
	GuiService.SelectedObject = nil
end

function BackpackUI.IsOpen()
	return isOpen
end

function BackpackUI.Toggle()
	if isOpen then close() else open() end
end

function BackpackUI.RefreshLootSlot()
	refreshBag()
end

function BackpackUI.RefreshEquipSlot()
	refreshEquipment()
	refreshStatus()
end

function BackpackUI.Init(inventoryModule, equipmentModule)
	Inventory = inventoryModule
	Equipment = equipmentModule
	updateWindowScale()
	bindViewportScaleUpdates()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		bindViewportScaleUpdates()
		updateWindowScale()
	end)

	local okAttachment, attachmentModule = pcall(function() return require(script.Parent:WaitForChild("AttachmentModule")) end)
	if okAttachment then Attachment = attachmentModule end
	local okCamera, cameraModule = pcall(function() return require(script.Parent:WaitForChild("CameraModule")) end)
	if okCamera then CameraModule = cameraModule end
	local okHUD, hudModule = pcall(function() return require(script.Parent:WaitForChild("HUDModule")) end)
	if okHUD then HUD = hudModule end

	for slotName, info in pairs(equipSlotFrames) do
		registerDraggable(info.button, function()
			local item = Equipment and Equipment.GetSlot(slotName) or nil
			if not item then return nil end
			return { kind = "equipment", slotName = slotName, item = makeEquipmentItem(item) }
		end, function()
			setSelected({ kind = "equipment", slotName = slotName })
		end, slotName)
		if info.attachmentButtons then
			for attachType, chip in pairs(info.attachmentButtons) do
				registerDraggable(chip, function()
					local weapon = Equipment and Equipment.GetSlot(slotName) or nil
					local attached = weapon and weapon.data and weapon.data.attachments and weapon.data.attachments[attachType] or nil
					if not attached then return nil end
					return {
						kind = "equipped_attachment",
						slotName = slotName,
						attachType = attachType,
						item = makeAttachmentInventoryItem(attached),
					}
				end, function()
					local weapon = Equipment and Equipment.GetSlot(slotName) or nil
					local attached = weapon and weapon.data and weapon.data.attachments and weapon.data.attachments[attachType] or nil
					if not attached then return end
					local clickKey = slotName .. ":" .. attachType
					local now = tick()
					if lastAttachmentClickKey == clickKey and (now - lastAttachmentClickAt) <= 0.3 then
						detachAttachmentToInventory(slotName, attachType)
						lastAttachmentClickKey = nil
						lastAttachmentClickAt = 0
					else
						lastAttachmentClickKey = clickKey
						lastAttachmentClickAt = now
						setSelected({ kind = "equipment", slotName = slotName })
					end
				end, slotName)
			end
		end
	end

	Inventory.OnSlotChanged(function()
		refreshBag()
		refreshStatus()
	end)
	if Inventory.OnLayoutChanged then
		Inventory.OnLayoutChanged(function() refreshBag() end)
	end
	Equipment.OnSlotChanged(function(slotName)
		if slotName == "vest" or slotName == "carrier" then rebuildPouches() end
		refreshEquipment()
		refreshStatus()
	end)

	player.CharacterAdded:Connect(function()
		if isOpen then task.wait(0.2); refreshPreviewModel() end
	end)

	UIS.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.Tab then
			BackpackUI.Toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and isOpen then
			close()
		elseif isOpen and (input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Backspace) then
			dropSelectedItem()
		end
	end)

	rebuildPouches()
	refreshBag()
	refreshEquipment()
	refreshStatus()
	print("[BackpackUI] Initialized with grid bag and vicinity support.")
end

return BackpackUI
