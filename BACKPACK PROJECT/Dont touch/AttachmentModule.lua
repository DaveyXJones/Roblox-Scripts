--==================================================
-- AttachmentModule
-- ModuleScript inside PlayerController > Modules
--
-- Manages attaching and detaching items from weapons.
-- Reads definitions from ItemRegistry.
-- WeaponModule reads the active weapon's attachments
-- to apply stat changes and sound swaps.
--
-- Usage:
--   AttachmentModule.Attach(weaponItem, attachmentItem)
--   AttachmentModule.Detach(weaponItem, attachType)
--   AttachmentModule.GetAttachment(weaponItem, attachType)
--   AttachmentModule.GetStats(weaponItem)
--==================================================

local AttachmentModule = {}

-- ============================================================
-- VALID ATTACH TYPES
-- ============================================================
AttachmentModule.TYPES = {
	SCOPE      = "scope",
	SUPPRESSOR = "suppressor",
	GRIP       = "grip",
}

-- ============================================================
-- ATTACH
-- Fits an attachment onto a weapon item table.
-- weaponItem  : item table (from inventory or equipment slot)
-- attachItem  : attachment item table (from ItemRegistry.Get)
-- Returns true on success, or false + reason string on failure.
-- ============================================================
function AttachmentModule.Attach(weaponItem, attachItem)
	if not weaponItem or not attachItem then
		return false, "nil argument"
	end

	local wData = weaponItem.data
	if not wData then
		return false, "weapon has no data table"
	end

	-- Make sure this weapon supports attachments at all
	if not wData.attachmentSlots then
		return false, "weapon has no attachment slots"
	end

	local attachType = attachItem.data and attachItem.data.attachType
	if not attachType then
		return false, "attachment has no attachType in data"
	end

	-- Check the weapon has this slot and it's enabled
	if not wData.attachmentSlots[attachType] then
		return false, "weapon does not support " .. attachType .. " slot"
	end

	-- Initialise the attachments table if it doesn't exist yet
	if not wData.attachments then
		wData.attachments = {}
	end

	-- Store a copy of the attachment data on the weapon
	wData.attachments[attachType] = {
		id          = attachItem.id,
		name        = attachItem.name,
		iconId      = attachItem.iconId or "",
		data        = attachItem.data,
	}

	return true
end

-- ============================================================
-- DETACH
-- Removes an attachment of the given type from a weapon.
-- Returns the removed attachment table, or nil if none fitted.
-- ============================================================
function AttachmentModule.Detach(weaponItem, attachType)
	if not weaponItem or not weaponItem.data then return nil end
	local attachments = weaponItem.data.attachments
	if not attachments then return nil end

	local removed = attachments[attachType]
	attachments[attachType] = nil
	return removed
end

-- ============================================================
-- GET ATTACHMENT
-- Returns the attachment table currently fitted in a slot,
-- or nil if that slot is empty.
-- ============================================================
function AttachmentModule.GetAttachment(weaponItem, attachType)
	if not weaponItem or not weaponItem.data then return nil end
	local attachments = weaponItem.data.attachments
	if not attachments then return nil end
	return attachments[attachType]
end

-- ============================================================
-- GET STATS
-- Returns a flat table of all stat modifiers currently active
-- on a weapon based on its fitted attachments.
-- WeaponModule and ScopeOverlay call this on every ADS/shot.
--
-- Returned table shape:
-- {
--   zoomFOV        : number   (from scope, default = weapon default ADS FOV)
--   aimSpread      : number   (multiplier, default 1.0)
--   recoilMulti    : number   (multiplier, default 1.0)
--   damageMulti    : number   (multiplier, default 1.0)
--   reticleId      : string   (scope overlay asset, "" = no overlay)
--   reticleSize    : number   (overlay scale, default 1)
--   isSuppressed   : bool
--   suppressedSnd  : string   (sound asset id, "" = none)
-- }
-- ============================================================
function AttachmentModule.GetStats(weaponItem)
	local stats = {
		zoomFOV       = 50,   -- sensible default ADS FOV
		aimSpread     = 1.0,
		recoilMulti   = 1.0,
		damageMulti   = 1.0,
		reticleId     = "",
		reticleSize   = 1,
		isSuppressed  = false,
		suppressedSnd = "",
	}

	if not weaponItem or not weaponItem.data then return stats end
	local attachments = weaponItem.data.attachments
	if not attachments then return stats end

	-- Scope
	local scope = attachments["scope"]
	if scope and scope.data then
		stats.zoomFOV     = scope.data.zoomFOV    or stats.zoomFOV
		stats.aimSpread   = scope.data.aimSpread   or stats.aimSpread
		stats.reticleId   = scope.data.reticleId   or ""
		stats.reticleSize = scope.data.reticleSize or 1
	end

	-- Suppressor
	local supp = attachments["suppressor"]
	if supp and supp.data then
		stats.isSuppressed  = true
		stats.damageMulti   = stats.damageMulti * (supp.data.damageMulti or 1.0)
		stats.suppressedSnd = supp.data.suppressedSnd or ""
	end

	-- Grip
	local grip = attachments["grip"]
	if grip and grip.data then
		stats.recoilMulti = stats.recoilMulti * (grip.data.recoilMulti or 1.0)
		stats.aimSpread   = stats.aimSpread   * (grip.data.aimSpread   or 1.0)
	end

	return stats
end

-- ============================================================
-- CAN ATTACH
-- Quick check: returns true if this attachment can legally
-- go on this weapon (slot exists and is enabled on the weapon).
-- ============================================================
function AttachmentModule.CanAttach(weaponItem, attachItem)
	if not weaponItem or not attachItem then return false end
	local wData = weaponItem.data
	if not wData or not wData.attachmentSlots then return false end
	local attachType = attachItem.data and attachItem.data.attachType
	if not attachType then return false end
	return wData.attachmentSlots[attachType] == true
end

print("[AttachmentModule] Loaded.")

return AttachmentModule
