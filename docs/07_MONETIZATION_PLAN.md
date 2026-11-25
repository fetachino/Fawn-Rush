# 07 — Monetization Plan

Owner: Monetization Specialist. Implementation owner: `MonetizationService`, `ShopService`,
`UI/Screens/GamepassShop`.

---

## 1. Principles

1. **Nothing that affects survival is for sale.** No speed, no hitbox, no hazard density, no
   leaderboard weighting. A paying player and a free player cross identically.
2. **Two currencies, one of them never sold.** Golden Acorns are earned only (`00` D6). This keeps a
   visible skill ladder and stops every interesting item from becoming a Robux item in disguise.
3. **No paid randomness.** No crate, no wheel, no roll, no Fortune-style product. Acorn-priced caches
   exist; their odds are published in the UI and they are duplicate-protected.
4. **Disclosed in plain language.** Every purchase states exactly and only what it does.
5. **Nothing expires that the player bought.** Passes are permanent. Limited cosmetics may leave the
   shop but never leave an inventory.
6. **No fake urgency.** No countdown on a normal item, no "only 3 left", no invented discount.
7. **Players can play the entire game for free.** All five worlds, all thirteen animals (skill routes),
   all missions, all achievements.

Realistic target: ARPDAU driven by cosmetics and convenience, not by spending walls. The economy is
designed so that the *only* thing money buys is time and expression, and the game stays legible to a
player who spends nothing.

---

## 2. Gamepasses

All IDs are `0` in `MonetizationConfig` until created in the Creator Dashboard. Price bands below are
launch-intent ranges, not commitments — Roblox requires the price to be set in the Dashboard, and the
source of truth for the *displayed* price is always `MarketplaceService:GetProductInfo`, never a
hard-coded number.

| # | Pass | Config key | Intent price (Robux) | Grants | Disclosure line |
|---|---|---|---|---|---|
| 1 | **VIP Pass** | `passes.vip` | 199–399 | VIP nameplate tag, 3 VIP cosmetics (crown, cape, gold trail), VIP lobby corner, exclusive emote, +250 acorns once | "Permanent. Cosmetic only. Does not affect gameplay." |
| 2 | **Extra Loadout Slots** | `passes.loadoutSlots` | 99–149 | 3 additional saved cosmetic loadouts (4 total) | "Permanent. Saves cosmetic sets. No gameplay effect." |
| 3 | **Cosmetic Bundle** | `passes.cosmeticBundle` | 299–499 | Exclusive animal colour variant set, matching scarf + back item, unique trail | "Permanent. Cosmetic only." |
| 4 | **Premium Trail Pack** | `passes.trailPack` | 149–249 | 5 exclusive trail effects | "Permanent. Cosmetic only." |
| 5 | **Double Acorns** | `passes.doubleAcorns` | 399–599 | ×2 on **standard earned acorns** (run pickups, row bonus, near-miss acorns) | "Permanent. Doubles acorns earned from runs. Does **not** affect Golden Acorns, mission rewards, achievements, purchases or event bonuses." |

### 2.1 The Double Acorns whitelist

This is the one pass that touches the economy, so it is implemented as an explicit source whitelist,
not a global multiplier:

```lua
-- EconomyConfig
DoubleAcornsSources = {
	acorn_safe = true, acorn_road = true, row_bonus = true,
	near_miss = true, run_completion = true,
	world_spotlight = false,     -- event bonus already boosted; never stacked
	mission = false, achievement = false, daily_login = false,
	purchase = false, golden = false,
}

-- CurrencyService:Grant
local mul = 1
if currency == "acorns" and profile.purchases.owned[PASS.DOUBLE_ACORNS]
	and EconomyConfig.DoubleAcornsSources[source] == true then
	mul = 2
end
```

A unit test asserts that every source key in the game appears in this table (default false) so a new
reward type can never silently become doubled.

---

## 3. Developer products

| # | Product | Config key | Robux | Grants | Notes |
|---|---|---|---|---|---|
| 1 | Small Acorn Pouch | `products.acornsSmall` | 49–99 | 1,000 acorns | |
| 2 | Medium Acorn Pack | `products.acornsMedium` | 149–249 | 3,300 acorns | Best-value-flag honest: 10% more per Robux |
| 3 | Large Acorn Crate | `products.acornsLarge` | 399–599 | 9,500 acorns | |
| 4 | Single Revive | `products.revive` | 49–99 | One revive, this run only | Max 1 per run; **does not restore combo** |
| 5 | Limited Cosmetic Bundle | `products.cosmeticBundle` | 249–449 | 1 outfit set + trail, seasonally rotated | Returns annually |

**Revive rules (the only gameplay-adjacent product).** It resurrects the player on the same tile with
0.6 s of invulnerability, keeps distance and acorns, and explicitly loses the combo (which is lost on
death anyway). It cannot be bought after the results screen, cannot be used twice in a run, and cannot
be used at all in Daily Gauntlet mode. It is disclosed as "saves your run, not your combo".

---

## 4. Never sold

Survival advantages · speed · extra lives beyond the single revive · leaderboard position · XP boosts
that affect rank · mission skips · access to worlds (worlds unlock by level and rows only) · animals
that are skill-exclusive (Bear Cub, Moonlit Fawn) · Golden Acorns · any randomised paid reward · any
mechanic that punishes non-payers.

---

## 5. Configuration file

`src/shared/Config/MonetizationConfig.luau` — the only file in the repository permitted to contain
product or pass ids.

```lua
--!strict
local MonetizationConfig = {}

MonetizationConfig.passes = {
	vip            = { id = 0, name = "VIP Pass",           priceHint = 299 },
	loadoutSlots   = { id = 0, name = "Extra Loadout Slots", priceHint = 99  },
	cosmeticBundle = { id = 0, name = "Cosmetic Bundle",     priceHint = 349 },
	trailPack      = { id = 0, name = "Premium Trail Pack",  priceHint = 199 },
	doubleAcorns   = { id = 0, name = "Double Acorns",       priceHint = 499 },
}

MonetizationConfig.products = {
	acornsSmall        = { id = 0, name = "Small Acorn Pouch",  acorns = 1000, priceHint = 49  },
	acornsMedium       = { id = 0, name = "Medium Acorn Pack",  acorns = 3300, priceHint = 149 },
	acornsLarge        = { id = 0, name = "Large Acorn Crate",  acorns = 9500, priceHint = 399 },
	revive             = { id = 0, name = "Revive",             priceHint = 49  },
	cosmeticBundle     = { id = 0, name = "Seasonal Bundle",    priceHint = 299 },
}

-- Reverse lookup built at load: productId -> key, passId -> key
function MonetizationConfig.resolveProduct(productId: number): string?
function MonetizationConfig.resolvePass(passId: number): string?
function MonetizationConfig.validate(): { warnings: { string } }   -- called at boot
```

`validate()` returns warnings (ids that are `0`, duplicate ids, ids that are not integers). Boot logs
them and every UI surface hides the unconfigured entry rather than showing a dead tile
(`02` §14).

---

## 6. Disclosure copy (UI-facing, final text)

- **Pass tiles:** name, what it grants (bullet list, max 3 lines), the permanent/cosmetic disclaimer,
  and the platform-reported price.
- **Product tiles:** name, exact acorn amount, price, and for the revive, "One use. Your combo is lost
  either way."
- **Shop footer:** "Purchases never affect how far you can run. Every world and every animal can be
  earned for free."
- **Pre-confirm modal** for every Robux purchase: item name, price, what changes, and a Cancel that is
  the same size as Confirm.
- **Post-purchase:** a `Toast` naming exactly what was granted, plus the item already being equipped
  where relevant.

---

## 7. `ProcessReceipt` implementation

The contract: it must return `PurchaseGranted` **only** after the grant is durably persisted, and it
may be called repeatedly for the same `PurchaseId`.

```lua
MarketplaceService.ProcessReceipt = function(receiptInfo)
	-- 1. Identify
	local userId = receiptInfo.PlayerId
	local productKey = MonetizationConfig.resolveProduct(receiptInfo.ProductId)
	if not productKey then
		Logger.warn("receipt", "unknown product " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 2. The player must be in this server; if not, do not consume the receipt.
	local player = Players:GetPlayerByUserId(userId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	-- 3. Acquire the profile; refuse rather than grant into the void
	local profile = PlayerDataService:Get(player)
	if not profile then return Enum.ProductPurchaseDecision.NotProcessedYet end

	-- 4. Serialise per player (a player may not have two receipts in flight)
	local lock = ReceiptLock.acquire(userId, 10)
	if not lock then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local released = false

	local ok, err = pcall(function()
		-- 5. Idempotency + grant in ONE atomic write
		local granted = ReceiptLedger.applyPurchase(player, profile, {
			purchaseId  = receiptInfo.PurchaseId,
			productKey  = productKey,
			productId   = receiptInfo.ProductId,
			robuxPrice  = receiptInfo.CurrencySpent,
			placeIdWherePurchased = receiptInfo.PlaceIdWherePurchased,
		}, function(profile)
			return MonetizationService.grantProduct(profile, productKey)
		end)

		if not granted.ok then
			error(granted.err, 2)   -- leaves the receipt unconsumed for a retry
		end
	end)

	if not released then lock.release() end
	if not ok then
		Logger.error("receipt", "grant failed for " .. player.Name .. ": " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
```

`ReceiptLedger.applyPurchase` performs a single `UpdateAsync` on the ledger key that (a) returns the
existing record untouched if the `purchaseId` is already present, marking the result as
`alreadyGranted`, and (b) otherwise writes the record **before** invoking the grant callback and then
commits the profile in the same protected section. The order is: reserve the receipt, grant into the
profile, save the profile, mark the receipt complete. A crash between any two steps leaves the receipt
reserved, and the retry finds the reservation, re-runs the (idempotent) grant against the profile, and
finishes.

Guards:
- `ProductPurchaseDecision.PurchaseGranted` is **never** returned if the profile save failed.
- Unknown product ids are logged and left unconsumed (so a config fix can still honour them).
- A receipt for a player no longer in the server is left unconsumed; Roblox retries it on their next
  visit, which is correct behaviour for a purchase.

---

## 8. Ownership checks and restore

- `MarketplaceService:UserOwnsGamePassAsync(userId, passId)` is called once on join for each configured
  pass, then **cached in the profile** (`purchases.owned[passKey] = true`), and re-verified on every
  join. Cache prevents a Marketplace outage from stripping a VIP's cosmetics mid-session.
- Passes are checked at the point of effect, not at purchase time: `MonetizationService:HasPass(player,
  key)` reads the profile cache.
- If a pass id is reconfigured, previously owned keys stay owned (keys are semantic, ids are not
  stored in the profile).
- `PromptGamePassPurchaseFinished` is treated as a hint to refresh ownership, never as the grant itself.
  Grants come from ownership queries, so a spoofed client event cannot grant anything.
- Products are never "owned"; they are consumed. `productCounts` is bookkeeping for support, not a
  gate.

---

## 9. Failure handling and edge cases

| Case | Behaviour |
|---|---|
| MarketplaceService unavailable at boot | Passes shown as unavailable, shop Robux tab shows an explanation, no crash |
| Purchase prompt cancelled | Nothing happens; no error toast (cancelling is not an error) |
| Receipt for an unknown product | Unconsumed, logged, surfaced in the dev overlay for support |
| Receipt while the profile failed to load | Unconsumed |
| Player leaves mid-purchase | Unconsumed; retried on next join |
| Duplicate receipt delivery | Existing ledger record → no second grant, returns `PurchaseGranted` |
| Grant succeeded but save failed | Receipt stays unconsumed; retry re-grants idempotently from the ledger reservation |
| Refund (support-initiated) | Ownership is re-queried on next join; if revoked, cosmetics lock (item stays but icon greys). Never delete an item a player used. |
| Region / age restriction | Roblox handles the prompt; our UI only hides nothing (no region gating of content) |

---

## 10. Analytics for monetization

Events (names fixed once shipped): `shop_open`, `shop_purchase`, `robux_purchase_attempt`,
`robux_purchase_complete`, `robux_purchase_fail`, `pass_ownership_refresh`, `revive_used`.
Tracked dimensions: product key, price band, player level bucket, session count bucket, whether the
player had already earned the equivalent acorns. No personal data. This exists to find *friction*, not
to build a spending-pressure model, and it never drives dynamic pricing (Roblox sets prices; we do not
personalise them).

---

## 11. Revenue sanity check

At a hypothetical 10,000 DAU with 2.5% paying and an average of 180 Robux per payer per month, gross is
~4,500,000 Robux/month before Roblox's cut. The economy is tuned so that a free player reaches every
animal's skill route in 6–10 hours, which is the actual retention lever; the shop is a tail, not the
engine. If the shop ever becomes the retention lever, the design has failed and this document should be
revisited.
