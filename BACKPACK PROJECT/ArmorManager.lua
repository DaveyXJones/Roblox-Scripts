--==================================================
-- ArmorManager
-- Script inside ServerScriptService
--
-- Receives armor data from clients (rating + durability)
-- and provides a damage reduction function that other
-- server scripts (ZombieAI, PvP, etc.) can call.
--
-- ARMOR FORMULA (Hybrid):
--   Percentage reduction: blocked = raw * (armorRating / 100)
--   Effective damage = raw - blocked  (minimum 1)
--   Durability loss = blocked / 2  (half the absorbed damage)
--   When durability reaches 0, that armor piece is destroyed.
--
-- SETUP:
--   Creates RemoteEvents inside
--   ReplicatedStorage.ZombieRemotes:
--     "SyncArmor"        – client ? server (equip/update)
--     "ArmorDurability"   – server ? client (durability changed)
--
-- USAGE (from other server scripts):
--   local ArmorManager = require(path.to.ArmorManager)
--   local reduced = ArmorManager.ReduceDamage(player, rawDamage)
--   hum:TakeDamage(reduced)
--==================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorManager = {}

-- ============================================================
-- REMOTE SETUP
-- ============================================================
local zombieRemotes = ReplicatedStorage:FindFirstChild("ZombieRemotes")
if not zombieRemotes then
	zombieRemotes = Instance.new("Folder", ReplicatedStorage)
	zombieRemotes.Name = "ZombieRemotes"
end

local RE_SyncArmor = zombieRemotes:FindFirstChild("SyncArmor")
if not RE_SyncArmor then
	RE_SyncArmor = Instance.new("RemoteEvent", zombieRemotes)
	RE_SyncArmor.Name = "SyncArmor"
end

local RE_ArmorDurability = zombieRemotes:FindFirstChild("ArmorDurability")
if not RE_ArmorDurability then
	RE_ArmorDurability = Instance.new("RemoteEvent", zombieRemotes)
	RE_ArmorDurability.Name = "ArmorDurability"
end

-- ============================================================
-- PLAYER ARMOR STORAGE
-- ============================================================
-- Each player stores:
--   playerArmor[userId] = {
--     helmet  = { rating = 30, durability = 30, maxDurability = 30 },
--     carrier = { rating = 40, durability = 40, maxDurability = 40 },
--   }
local playerArmor = {}

-- Listen for armor updates from clients (when they equip/unequip)
RE_SyncArmor.OnServerEvent:Connect(function(player, armorData)
	-- Validate: must be a table with helmet/carrier info
	if type(armorData) ~= "table" then return end

	local userId = player.UserId
	if not playerArmor[userId] then
		playerArmor[userId] = {}
	end

	-- Update helmet
	if armorData.helmet then
		if type(armorData.helmet) == "table"
			and type(armorData.helmet.rating) == "number"
			and type(armorData.helmet.durability) == "number"
			and type(armorData.helmet.maxDurability) == "number" then
			playerArmor[userId].helmet = {
				rating        = math.clamp(math.floor(armorData.helmet.rating), 0, 100),
				durability    = math.clamp(armorData.helmet.durability, 0, 200),
				maxDurability = math.clamp(armorData.helmet.maxDurability, 0, 200),
			}
		end
	else
		playerArmor[userId].helmet = nil
	end

	-- Update carrier
	if armorData.carrier then
		if type(armorData.carrier) == "table"
			and type(armorData.carrier.rating) == "number"
			and type(armorData.carrier.durability) == "number"
			and type(armorData.carrier.maxDurability) == "number" then
			playerArmor[userId].carrier = {
				rating        = math.clamp(math.floor(armorData.carrier.rating), 0, 100),
				durability    = math.clamp(armorData.carrier.durability, 0, 200),
				maxDurability = math.clamp(armorData.carrier.maxDurability, 0, 200),
			}
		end
	else
		playerArmor[userId].carrier = nil
	end
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
	playerArmor[player.UserId] = nil
end)

-- ============================================================
-- PUBLIC API
-- ============================================================

-- Returns the combined armor rating (used for display/info only)
function ArmorManager.GetArmor(player)
	if not player then return 0 end
	local data = playerArmor[player.UserId]
	if not data then return 0 end
	local total = 0
	if data.helmet  and data.helmet.durability  > 0 then total = total + data.helmet.rating  end
	if data.carrier and data.carrier.durability > 0 then total = total + data.carrier.rating end
	return total
end

-- Reduces raw damage by the player's armor (hybrid percentage system).
-- Also degrades armor durability and notifies the client.
-- Returns the damage amount that gets through to health.
function ArmorManager.ReduceDamage(player, rawDamage)
	if not player then return rawDamage end
	local data = playerArmor[player.UserId]
	if not data then return rawDamage end

	-- Combine effective armor rating from pieces with remaining durability
	local totalRating = 0
	local pieces = {}  -- track which pieces absorb damage

	if data.helmet and data.helmet.durability > 0 then
		totalRating = totalRating + data.helmet.rating
		table.insert(pieces, "helmet")
	end
	if data.carrier and data.carrier.durability > 0 then
		totalRating = totalRating + data.carrier.rating
		table.insert(pieces, "carrier")
	end

	if totalRating <= 0 then return rawDamage end

	-- Cap effective rating at 90% to always let some damage through
	local effectivePercent = math.min(totalRating, 90) / 100
	local blocked = rawDamage * effectivePercent
	local finalDamage = math.max(1, rawDamage - blocked)

	-- Degrade durability: each piece loses (its share of blocked / 2)
	-- Split durability damage proportionally by each piece's rating
	local durabilityChanged = false
	for _, pieceName in ipairs(pieces) do
		local piece = data[pieceName]
		local share = piece.rating / totalRating  -- proportion of protection
		local durLoss = (blocked * share) / 2     -- half the absorbed damage
		piece.durability = math.max(0, piece.durability - durLoss)

		if piece.durability <= 0 then
			-- Armor piece destroyed
			piece.durability = 0
		end
		durabilityChanged = true
	end

	-- Notify the client about new durability values
	if durabilityChanged then
		local clientData = {}
		if data.helmet then
			clientData.helmet = {
				durability    = data.helmet.durability,
				maxDurability = data.helmet.maxDurability,
				destroyed     = data.helmet.durability <= 0,
			}
		end
		if data.carrier then
			clientData.carrier = {
				durability    = data.carrier.durability,
				maxDurability = data.carrier.maxDurability,
				destroyed     = data.carrier.durability <= 0,
			}
		end
		RE_ArmorDurability:FireClient(player, clientData)
	end

	return finalDamage
end

print("[ArmorManager] Initialized (hybrid % reduction + durability).")

return ArmorManager