--==================================================
-- LootTableModule
-- ModuleScript ? ReplicatedStorage
--==================================================

local LootTableModule = {}

LootTableModule.TIER = {
	CIVILIAN = "civilian",
	MID      = "mid",
	MILITARY = "military",
}

LootTableModule.CONTEXT = {
	FOOD        = "food",
	WATER       = "water",
	MEDICAL     = "medical",
	AMMO_PISTOL = "ammo_pistol",
	AMMO_AR     = "ammo_ar",
	AMMO_ANY    = "ammo_any",
	WEAPON      = "weapon",
	MELEE       = "melee",
	GRENADE     = "grenade",
	ATTACHMENT  = "attachment",
	GEAR        = "gear",
	CLOTHING    = "clothing",
	RANDOM      = "random",
}

LootTableModule.RESPAWN_TIME = 120

LootTableModule.CHEST_COUNT = {
	civilian = { min = 1, max = 2 },
	mid      = { min = 2, max = 3 },
	military = { min = 3, max = 4 },
}

LootTableModule.ITEMS = {

	-- ============================================================
	-- FOOD
	-- ============================================================
	{
		name     = "Canned Beans",
		type     = "Heal",
		quantity = { min = 1, max = 2 },
		maxStack = 5,
		iconId   = "",
		weight   = 40,
		tiers    = { "civilian", "mid", "military" },
		contexts = { "food", "random" },
		data     = { hungerRestore = 40 },
	},
	{
		name     = "Energy Bar",
		type     = "Heal",
		quantity = { min = 1, max = 3 },
		maxStack = 8,
		iconId   = "rbxassetid://18377035199",
		weight   = 35,
		tiers    = { "civilian", "mid", "military" },
		contexts = { "food", "random" },
		data     = { hungerRestore = 40 },
	},
	{
		name     = "MRE Pack",
		type     = "Heal",
		quantity = { min = 1, max = 1 },
		maxStack = 3,
		iconId   = "",
		weight   = 20,
		tiers    = { "mid", "military" },
		contexts = { "food", "random" },
		data     = { hungerRestore = 60 },
	},
	{
		name     = "Protein Bar",
		type     = "Heal",
		quantity = { min = 1, max = 2 },
		maxStack = 6,
		iconId   = "",
		weight   = 30,
		tiers    = { "civilian", "mid" },
		contexts = { "food", "random" },
		data     = { hungerRestore = 30 },
	},
	{
		name     = "Ration Pack",
		type     = "Heal",
		quantity = { min = 1, max = 2 },
		maxStack = 3,
		iconId   = "",
		weight   = 20,
		tiers    = { "mid", "military" },
		contexts = { "food", "random" },
		data     = { hungerRestore = 50 },
	},

	-- ============================================================
	-- WATER
	-- ============================================================
	{
		name     = "Water Bottle",
		type     = "Heal",
		quantity = { min = 1, max = 2 },
		maxStack = 4,
		iconId   = "",
		weight   = 40,
		tiers    = { "civilian", "mid", "military" },
		contexts = { "water", "random" },
		data     = { waterRestore = 50 },
	},
	{
		name     = "Canteen",
		type     = "Heal",
		quantity = { min = 1, max = 1 },
		maxStack = 2,
		iconId   = "rbxassetid://13612735175",
		weight   = 25,
		tiers    = { "mid", "military" },
		contexts = { "water", "random" },
		data     = { waterRestore = 75 },
	},
	{
		name     = "Purification Tablet",
		type     = "Misc",
		quantity = { min = 1, max = 3 },
		maxStack = 10,
		iconId   = "",
		weight   = 20,
		tiers    = { "civilian", "mid" },
		contexts = { "water", "random" },
	},

	-- ============================================================
	-- MEDICAL
	-- ============================================================
	{
		name     = "Bandage",
		type     = "Heal",
		quantity = { min = 1, max = 3 },
		maxStack = 10,
		iconId   = "rbxassetid://73097467153662",
		weight   = 45,
		tiers    = { "civilian", "mid", "military" },
		contexts = { "medical", "random" },
		data     = { healAmount = 25 },
	},
	{
		name     = "Med Kit",
		type     = "Heal",
		quantity = { min = 1, max = 1 },
		maxStack = 3,
		iconId   = "rbxassetid://113643903183725",
		weight   = 20,
		tiers    = { "mid", "military" },
		contexts = { "medical", "random" },
		data     = { healAmount = 75 },
	},
	{
		name     = "Painkillers",
		type     = "Heal",
		quantity = { min = 1, max = 2 },
		maxStack = 6,
		iconId   = "rbxassetid://12342111158",
		weight   = 30,
		tiers    = { "civilian", "mid", "military" },
		contexts = { "medical", "random" },
		data     = { healAmount = 40 },
	},
	{
		name     = "Antiseptic",
		type     = "Heal",
		quantity = { min = 1, max = 1 },
		maxStack = 4,
		iconId   = "",
		weight   = 25,
		tiers    = { "civilian", "mid" },
		contexts = { "medical", "random" },
		data     = { healAmount = 15 },
	},
	{
		name     = "Adrenaline Shot",
		type     = "Heal",
		quantity = { min = 1, max = 1 },
		maxStack = 2,
		iconId   = "",
		weight   = 8,
		tiers    = { "military" },
		contexts = { "medical", "random" },
		data     = { healAmount = 50 },
	},

	-- ============================================================
	-- AMMO — PISTOL
	-- ============================================================
	{
		name     = "9mm Rounds",
		type     = "Ammo",
		quantity = { min = 6, max = 15 },
		maxStack = 120,
		iconId   = "",
		weight   = 50,
		tiers    = { "civilian", "mid", "military" },
		contexts = { "ammo_pistol", "ammo_any", "random" },
	},
	{
		name     = "9mm Hollow Point",
		type     = "Ammo",
		quantity = { min = 4, max = 10 },
		maxStack = 60,
		iconId   = "",
		weight   = 20,
		tiers    = { "mid", "military" },
		contexts = { "ammo_pistol", "ammo_any" },
	},
	{
		name     = ".50 AE Rounds",
		type     = "Ammo",
		quantity = { min = 3, max = 7 },
		maxStack = 35,
		iconId   = "",
		weight   = 10,
		tiers    = { "military" },
		contexts = { "ammo_pistol", "ammo_any" },
	},

	-- ============================================================
	-- AMMO — RIFLE / AR
	-- ============================================================
	{
		name     = "5.56 Rounds",
		type     = "Ammo",
		quantity = { min = 10, max = 30 },
		maxStack = 200,
		iconId   = "",
		weight   = 45,
		tiers    = { "mid", "military" },
		contexts = { "ammo_ar", "ammo_any", "random" },
	},
	{
		name     = "5.56 AP Rounds",
		type     = "Ammo",
		quantity = { min = 5, max = 15 },
		maxStack = 100,
		iconId   = "",
		weight   = 15,
		tiers    = { "military" },
		contexts = { "ammo_ar", "ammo_any" },
	},
	{
		name     = "7.62 Rounds",
		type     = "Ammo",
		quantity = { min = 8, max = 20 },
		maxStack = 120,
		iconId   = "",
		weight   = 35,
		tiers    = { "mid", "military" },
		contexts = { "ammo_ar", "ammo_any", "random" },
	},
	{
		name     = "12G Shells",
		type     = "Ammo",
		quantity = { min = 2, max = 8 },
		maxStack = 40,
		iconId   = "",
		weight   = 25,
		tiers    = { "civilian", "mid" },
		contexts = { "ammo_any", "random" },
	},
	{
		name     = "Loose Shotgun Shells",
		type     = "Ammo",
		quantity = { min = 2, max = 8 },
		maxStack = 40,
		iconId   = "",
		weight   = 25,
		tiers    = { "civilian", "mid" },
		contexts = { "ammo_any", "random" },
	},

	-- ============================================================
	-- WEAPONS — PRIMARY
	-- type must match EquipmentModule.SLOT_ACCEPTS["primary"]
	-- ============================================================
	{
		name     = "M4A1",
		type     = "primary",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 65,
		tiers    = { "military" },
		contexts = { "weapon", "random" },
		data     = {
			weaponSlot      = "primary",
			damage          = 22,
			fireRate        = 0.09,
			reloadTime      = 2.5,
			maxAmmo         = 30,
			ammoType        = "5.56 Rounds",
			fireModes       = { "Semi", "Auto", "Burst" },
			defaultMode     = 2,
			attachmentSlots = { scope = true, suppressor = true, grip = true },
			attachments     = {},
			assetName       = "ARVM",
		},
	},
	{
		name     = "SCAR-L",
		type     = "primary",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 65,
		tiers    = { "military" },
		contexts = { "weapon", "random" },
		data     = {
			weaponSlot      = "primary",
			damage          = 22,
			fireRate        = 0.09,
			reloadTime      = 2.5,
			maxAmmo         = 30,
			ammoType        = "5.56 Rounds",
			fireModes       = { "Semi", "Auto", "Burst" },
			defaultMode     = 2,
			attachmentSlots = { scope = true, suppressor = true, grip = true },
			attachments     = {},
			assetName       = "SCAR-LVM",
		},
	},
	{
		name     = "AK-74",
		type     = "primary",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 15,
		tiers    = { "mid", "military" },
		contexts = { "weapon", "random" },
		data     = {
			weaponSlot      = "primary",
			damage          = 28,
			fireRate        = 0.11,
			reloadTime      = 2.8,
			maxAmmo         = 30,
			ammoType        = "7.62 Rounds",
			fireModes       = { "Semi", "Auto" },
			defaultMode     = 2,
			attachmentSlots = { scope = true, suppressor = true, grip = true },
			attachments     = {},
			assetName       = "AK74VM",
		},
	},
	{
		name     = "MP5",
		type     = "primary",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 20,
		tiers    = { "mid", "military" },
		contexts = { "weapon", "random" },
		data     = {
			weaponSlot      = "primary",
			damage          = 16,
			fireRate        = 0.07,
			reloadTime      = 2.0,
			maxAmmo         = 30,
			ammoType        = "9mm Rounds",
			fireModes       = { "Semi", "Auto" },
			defaultMode     = 2,
			attachmentSlots = { scope = true, suppressor = true, grip = true },
			attachments     = {},
			assetName       = "MP5VM",
		},
	},
	{
		name     = "M870",
		type     = "primary",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 25,
		tiers    = { "civilian", "mid" },
		contexts = { "weapon", "random" },
		data     = {
			weaponSlot      = "primary",
			damage          = 80,
			fireRate        = 0.9,
			reloadTime      = 3.2,
			maxAmmo         = 8,
			ammoType        = "12G Shells",
			fireModes       = { "Pump" },
			defaultMode     = 1,
			attachmentSlots = { scope = false, suppressor = false, grip = true },
			attachments     = {},
			assetName       = "M870VM",
		},
	},
	{
		name     = "SVD",
		type     = "primary",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 8,
		tiers    = { "military" },
		contexts = { "weapon", "random" },
		data     = {
			weaponSlot      = "primary",
			damage          = 65,
			fireRate        = 0.4,
			reloadTime      = 3.0,
			maxAmmo         = 10,
			ammoType        = "7.62 Rounds",
			fireModes       = { "Semi" },
			defaultMode     = 1,
			attachmentSlots = { scope = true, suppressor = true, grip = false },
			attachments     = {},
			assetName       = "SVDVM",
		},
	},
	-- Legacy entry kept for compatibility
	{
		name     = "Massive Machine Gun",
		type     = "primary",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 35,
		tiers    = { "civilian", "mid" },
		contexts = { "random" },
		data     = {
			weaponSlot      = "primary",
			damage          = 35,
			fireRate        = 0.08,
			reloadTime      = 3.5,
			maxAmmo         = 50,
			ammoType        = "5.56 Rounds",
			fireModes       = { "Auto" },
			defaultMode     = 1,
			attachmentSlots = { scope = true, suppressor = false, grip = true },
			attachments     = {},
			assetName       = "ARVM",
		},
	},

	-- ============================================================
	-- WEAPONS — SECONDARY
	-- ============================================================
	{
		name     = "P226",
		type     = "secondary",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 30,
		tiers    = { "civilian", "mid", "military" },
		contexts = { "weapon", "random" },
		data     = {
			weaponSlot      = "secondary",
			damage          = 28,
			fireRate        = 0.22,
			reloadTime      = 1.8,
			maxAmmo         = 15,
			ammoType        = "9mm Rounds",
			fireModes       = { "Semi" },
			defaultMode     = 1,
			attachmentSlots = { scope = false, suppressor = true, grip = false },
			attachments     = {},
			assetName       = "P226",
		},
	},
	{
		name     = "Desert Eagle",
		type     = "secondary",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 30,
		tiers    = { "military" },
		contexts = { "weapon", "random" },
		data     = {
			weaponSlot      = "secondary",
			damage          = 55,
			fireRate        = 0.35,
			reloadTime      = 2.0,
			maxAmmo         = 7,
			ammoType        = ".50 AE Rounds",
			fireModes       = { "Semi" },
			defaultMode     = 1,
			attachmentSlots = { scope = false, suppressor = false, grip = false },
			attachments     = {},
			assetName       = "DeagleVM",
		},
	},

	-- ============================================================
	-- WEAPONS — MELEE
	-- ============================================================
	{
		name     = "Combat Knife",
		type     = "melee",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 40,
		tiers    = { "civilian", "mid", "military" },
		contexts = { "melee", "random" },
		data     = {
			damage    = 45,
			range     = 4,
			swingRate = 0.5,
			canBlock  = false,
			assetName = "CombatKnifeVM",
		},
	},
	{
		name     = "Machete",
		type     = "melee",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 30,
		tiers    = { "civilian", "mid" },
		contexts = { "melee", "random" },
		data     = {
			damage    = 70,
			range     = 5,
			swingRate = 0.85,
			canBlock  = false,
			assetName = "MacheteVM",
		},
	},
	{
		name     = "Baseball Bat",
		type     = "melee",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 35,
		tiers    = { "civilian" },
		contexts = { "melee", "random" },
		data     = {
			damage    = 50,
			range     = 5,
			swingRate = 0.75,
			canBlock  = true,
			assetName = "BatVM",
		},
	},
	{
		name     = "Fire Axe",
		type     = "melee",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 20,
		tiers    = { "civilian", "mid" },
		contexts = { "melee", "random" },
		data     = {
			damage    = 90,
			range     = 5,
			swingRate = 1.1,
			canBlock  = false,
			assetName = "FireAxeVM",
		},
	},

	-- ============================================================
	-- GRENADES / THROWABLES
	-- ============================================================
	{
		name     = "Frag Grenade",
		type     = "grenade",
		quantity = { min = 1, max = 2 },
		maxStack = 4,
		iconId   = "",
		weight   = 10,
		tiers    = { "military" },
		contexts = { "grenade", "random" },
		data     = {
			fuseTime    = 4,
			blastRadius = 12,
			damage      = 100,
			grenadeType = "frag",
			assetName   = "FragGrenade",
		},
	},
	{
		name     = "Smoke Grenade",
		type     = "grenade",
		quantity = { min = 1, max = 2 },
		maxStack = 4,
		iconId   = "",
		weight   = 15,
		tiers    = { "mid", "military" },
		contexts = { "grenade", "random" },
		data     = {
			fuseTime    = 1,
			blastRadius = 0,
			damage      = 0,
			grenadeType = "smoke",
			assetName   = "SmokeGrenade",
		},
	},
	{
		name     = "Flashbang",
		type     = "grenade",
		quantity = { min = 1, max = 1 },
		maxStack = 3,
		iconId   = "",
		weight   = 12,
		tiers    = { "mid", "military" },
		contexts = { "grenade", "random" },
		data     = {
			fuseTime    = 2,
			blastRadius = 10,
			damage      = 0,
			grenadeType = "flashbang",
			assetName   = "Flashbang",
		},
	},
	{
		name     = "Molotov Cocktail",
		type     = "grenade",
		quantity = { min = 1, max = 1 },
		maxStack = 2,
		iconId   = "",
		weight   = 10,
		tiers    = { "civilian", "mid" },
		contexts = { "grenade", "random" },
		data     = {
			fuseTime    = 0,
			blastRadius = 8,
			damage      = 15,
			grenadeType = "molotov",
			assetName   = "Molotov",
		},
	},

	-- ============================================================
	-- ATTACHMENTS
	-- type must match exactly for AttachmentModule.CanAttach()
	-- data.attachType tells the system which slot it fits
	-- ============================================================
	{
		name     = "Red Dot Sight",
		type     = "scope",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 10,
		tiers    = { "mid", "military" },
		contexts = { "attachment", "random" },
		data     = {
			attachType  = "scope",
			zoomFOV     = 42,
			aimSpread   = 0.9,
			reticleId   = "",
			reticleSize = 1,
		},
	},
	{
		name     = "ACOG",
		type     = "scope",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 6,
		tiers    = { "military" },
		contexts = { "attachment", "random" },
		data     = {
			attachType  = "scope",
			zoomFOV     = 25,
			aimSpread   = 0.75,
			reticleId   = "",
			reticleSize = 1,
		},
	},
	{
		name     = "Sniper Scope",
		type     = "scope",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 4,
		tiers    = { "military" },
		contexts = { "attachment" },
		data     = {
			attachType  = "scope",
			zoomFOV     = 15,
			aimSpread   = 0.6,
			reticleId   = "",
			reticleSize = 1.2,
		},
	},
	{
		name     = "Suppressor",
		type     = "suppressor",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 56,
		tiers    = { "military" },
		contexts = { "attachment", "random" },
		data     = {
			attachType    = "suppressor",
			damageMulti   = 0.92,
			suppressedSnd = "",
		},
	},
	{
		name     = "7.62 Suppressor",
		type     = "suppressor",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 4,
		tiers    = { "military" },
		contexts = { "attachment" },
		data     = {
			attachType    = "suppressor",
			damageMulti   = 0.88,
			suppressedSnd = "",
		},
	},
	{
		name     = "Vertical Grip",
		type     = "grip",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 12,
		tiers    = { "mid", "military" },
		contexts = { "attachment", "random" },
		data     = {
			attachType  = "grip",
			recoilMulti = 0.75,
			aimSpread   = 0.9,
		},
	},
	{
		name     = "Angled Grip",
		type     = "grip",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 8,
		tiers    = { "military" },
		contexts = { "attachment", "random" },
		data     = {
			attachType  = "grip",
			recoilMulti = 0.85,
			aimSpread   = 0.85,
		},
	},

	-- ============================================================
	-- GEAR — HELMETS
	-- ============================================================
	{
		name     = "Baseball Cap",
		type     = "helmet",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 30,
		tiers    = { "civilian" },
		contexts = { "gear", "random" },
		data     = { armorRating = 0, slot = "helmet", clothingId = "" },
	},
	{
		name     = "Helmet (Level 1)",
		type     = "helmet",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 25,
		tiers    = { "civilian", "mid" },
		contexts = { "gear", "random" },
		data     = { armorRating = 15, slot = "helmet", clothingId = "" },
	},
	{
		name     = "Helmet (Level 2)",
		type     = "helmet",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 18,
		tiers    = { "mid", "military" },
		contexts = { "gear", "random" },
		data     = { armorRating = 30, slot = "helmet", clothingId = "" },
	},
	{
		name     = "Helmet (Level 3)",
		type     = "helmet",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 8,
		tiers    = { "military" },
		contexts = { "gear", "random" },
		data     = { armorRating = 50, slot = "helmet", clothingId = "" },
	},

	-- ============================================================
	-- GEAR — PLATE CARRIERS
	-- ============================================================
	{
		name     = "Chest Rig",
		type     = "carrier",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 25,
		tiers    = { "civilian", "mid" },
		contexts = { "gear", "random" },
		data     = { armorRating = 0, slot = "carrier", pouchSlots = 2, clothingId = "" },
	},
	{
		name     = "Plate Carrier (Level 1)",
		type     = "carrier",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 20,
		tiers    = { "mid" },
		contexts = { "gear", "random" },
		data     = { armorRating = 20, slot = "carrier", pouchSlots = 3, clothingId = "" },
	},
	{
		name     = "Plate Carrier (Level 2)",
		type     = "carrier",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 15,
		tiers    = { "mid", "military" },
		contexts = { "gear", "random" },
		data     = { armorRating = 40, slot = "carrier", pouchSlots = 4, clothingId = "" },
	},
	{
		name     = "Plate Carrier (Level 3)",
		type     = "carrier",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 6,
		tiers    = { "military" },
		contexts = { "gear" },
		data     = { armorRating = 60, slot = "carrier", pouchSlots = 5, clothingId = "" },
	},

	-- ============================================================
	-- CLOTHING — CHEST
	-- ============================================================
	{
		name     = "T-Shirt",
		type     = "chest",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 40,
		tiers    = { "civilian" },
		contexts = { "clothing", "random" },
		data     = { slot = "chest", speedMulti = 1.0, stealthBonus = 0, clothingId = "" },
	},
	{
		name     = "Military Jacket",
		type     = "chest",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 25,
		tiers    = { "mid", "military" },
		contexts = { "clothing", "random" },
		data     = { slot = "chest", speedMulti = 1.0, stealthBonus = 5, clothingId = "" },
	},
	{
		name     = "Ghillie Top",
		type     = "chest",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 5,
		tiers    = { "military" },
		contexts = { "clothing" },
		data     = { slot = "chest", speedMulti = 0.92, stealthBonus = 25, clothingId = "" },
	},

	-- ============================================================
	-- CLOTHING — LEGS
	-- ============================================================
	{
		name     = "Jeans",
		type     = "legs",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 40,
		tiers    = { "civilian" },
		contexts = { "clothing", "random" },
		data     = { slot = "legs", speedMulti = 1.0, stealthBonus = 0, clothingId = "" },
	},
	{
		name     = "Military Pants",
		type     = "legs",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 25,
		tiers    = { "mid", "military" },
		contexts = { "clothing", "random" },
		data     = { slot = "legs", speedMulti = 1.0, stealthBonus = 3, clothingId = "" },
	},
	{
		name     = "Ghillie Legs",
		type     = "legs",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 5,
		tiers    = { "military" },
		contexts = { "clothing" },
		data     = { slot = "legs", speedMulti = 0.92, stealthBonus = 25, clothingId = "" },
	},

	-- ============================================================
	-- CLOTHING — FEET
	-- ============================================================
	{
		name     = "Sneakers",
		type     = "feet",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 5,
		tiers    = { "civilian" },
		contexts = { "clothing", "random" },
		data     = { slot = "feet", speedMulti = 1.0, stealthBonus = 5, clothingId = "" },
	},
	{
		name     = "Combat Boots",
		type     = "feet",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 0,
		tiers    = { "civilian", "mid" },
		contexts = { "clothing", "random" },
		data     = { slot = "feet", speedMulti = 0.97, stealthBonus = 0, clothingId = "" },
	},
	{
		name     = "Tactical Boots",
		type     = "feet",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 5,
		tiers    = { "mid", "military" },
		contexts = { "clothing", "random" },
		data     = { slot = "feet", speedMulti = 1.0, stealthBonus = 2, clothingId = "" },
	},

	-- ============================================================
	-- MISC
	-- ============================================================
	{
		name     = "Flashlight",
		type     = "Misc",
		quantity = { min = 1, max = 1 },
		maxStack = 1,
		iconId   = "",
		weight   = 10,
		tiers    = { "civilian", "mid", "military" },
		contexts = { "random" },
	},
	{
		name     = "Duct Tape",
		type     = "Misc",
		quantity = { min = 1, max = 2 },
		maxStack = 5,
		iconId   = "",
		weight   = 25,
		tiers    = { "civilian", "mid" },
		contexts = { "random" },
	},
}

-- ============================================================
-- ROLL HELPER
-- ============================================================
function LootTableModule.Roll(tier, context)
	local pool = {}
	local totalWeight = 0

	for _, item in ipairs(LootTableModule.ITEMS) do
		local tierOk = false
		for _, t in ipairs(item.tiers) do
			if t == tier then tierOk = true; break end
		end

		local contextOk = false
		for _, c in ipairs(item.contexts) do
			if c == context then contextOk = true; break end
		end

		if tierOk and contextOk then
			table.insert(pool, item)
			totalWeight = totalWeight + item.weight
		end
	end

	if #pool == 0 or totalWeight == 0 then
		return nil
	end

	local function copyData(item)
		if not item.data then return {} end
		local d = {}
		for k, v in pairs(item.data) do
			if type(v) == "table" then
				local t = {}
				for k2, v2 in pairs(v) do t[k2] = v2 end
				d[k] = t
			elseif type(v) ~= "function" then
				d[k] = v
			end
		end
		return d
	end

	local roll = math.random(1, totalWeight)
	local cumulative = 0
	for _, item in ipairs(pool) do
		cumulative = cumulative + item.weight
		if roll <= cumulative then
			return {
				name     = item.name,
				type     = item.type,
				quantity = math.random(item.quantity.min, item.quantity.max),
				maxStack = item.maxStack,
				iconId   = item.iconId,
				data     = copyData(item),
			}
		end
	end

	local fallback = pool[#pool]
	return {
		name     = fallback.name,
		type     = fallback.type,
		quantity = math.random(fallback.quantity.min, fallback.quantity.max),
		maxStack = fallback.maxStack,
		iconId   = fallback.iconId,
		data     = copyData(fallback),
	}
end

return LootTableModule