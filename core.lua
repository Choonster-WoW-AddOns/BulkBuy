local MAX_STACK = 10000 -- The maximum stack size accepted by the stack split frame.

-----------------
--END OF CONFIG--
-----------------

--@debug@
-- Type annotations for Lua Language Server
if false then
	--- Classic-only
	---@param maxStack number
	_G.UpdateStackSplitFrame = function(maxStack) end

	--- Classic-only
	---@type FontString
	_G.StackSplitText = nil

	--- Classic-only
	---@type Button
	_G.StackSplitLeftButton = nil

	--- Classic-only
	---@type Button
	_G.StackSplitRightButton = nil

	---@class MerchantItemButton : Button
	---@field hasStackSplit number
	---@field extendedCost boolean
	---@field showNonrefundablePrompt boolean
end
--@end-debug@

---@type fun(index: number, quantity?: number)
local _BuyMerchantItem

local function SetBuyMerchantItem()
	_BuyMerchantItem = _G.BuyMerchantItem
end

local C_MerchantFrame_GetItemInfo

if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
	--- Returns info for a merchant item
	C_MerchantFrame_GetItemInfo = C_MerchantFrame.GetItemInfo
else
	--- Returns info for a merchant item
	---@param index number
	---@return MerchantItemInfo info
	C_MerchantFrame_GetItemInfo = function(index)
		local name, texture, price, stackCount, numAvailable, isPurchasable, isUsable, extendedCost, currencyID, spellID =
			GetMerchantItemInfo(index)

		return {
			name = name,
			texture = texture,
			price = price,
			stackCount = stackCount,
			numAvailable = numAvailable,
			isPurchasable = isPurchasable,
			isUsable = isUsable,
			hasExtendedCost = extendedCost,
			currencyID = currencyID,
			spellID = spellID
		}
	end
end

---@param index number
---@param quantity number
local function BulkBuyMerchantItem(index, quantity)
	local stackSize = GetMerchantItemMaxStack(index)
	local info      = C_MerchantFrame_GetItemInfo(index)

	-- If the item is sold for a non-gold currency and can only be bought in stacks of `stackCount`, buy the largest multiple of `stackCount` less than `amount` possible.
	if info.price <= 0 then
		quantity = math.floor(quantity / info.stackCount) * info.stackCount
	end

	-- Otherwise the item is sold for gold, so buy `amount` items

	while quantity > stackSize do -- Buy as many full stacks as we can
		_BuyMerchantItem(index, stackSize)
		quantity = quantity - stackSize
	end

	if quantity > 0 then -- Buy any leftover items
		_BuyMerchantItem(index, quantity)
	end
end

--- Wrapper around the default MerchantFrame_ConfirmExtendedItemCost function that temporarily replaces BuyMerchantItem with BulkBuyMerchantItem
---@param itemButton MerchantItemButton
---@param numToPurchase number
local function MerchantFrame_ConfirmExtendedBulkItemCost(itemButton, numToPurchase)
	SetBuyMerchantItem()
	_G.BuyMerchantItem = BulkBuyMerchantItem
	MerchantFrame_ConfirmExtendedItemCost(itemButton, numToPurchase)
	_G.BuyMerchantItem = _BuyMerchantItem
end

---@param self MerchantItemButton
---@param split number
local function MerchantItemButton_SplitStack(self, split)
	if self.extendedCost then
		MerchantFrame_ConfirmExtendedBulkItemCost(self, split)
	elseif self.showNonrefundablePrompt then
		MerchantFrame_ConfirmExtendedBulkItemCost(self, split)
	elseif split > 0 then
		SetBuyMerchantItem()
		BulkBuyMerchantItem(self:GetID(), split)
	end
end

-- Overwrite the default UI's SplitStack method
-- There are 12 MerchantItemXItemButtons, but the merchant frame only uses the first 10; the others are only used by the buyback window
for i = 1, 10 do
	local button = _G["MerchantItem" .. i .. "ItemButton"]
	button.SplitStack = MerchantItemButton_SplitStack
end

local function ConfirmPopup_OnAccept()
	SetBuyMerchantItem()
	BulkBuyMerchantItem(MerchantFrame.itemIndex, MerchantFrame.count or 1)
end

StaticPopupDialogs["CONFIRM_PURCHASE_TOKEN_ITEM"].OnAccept = ConfirmPopup_OnAccept
StaticPopupDialogs["CONFIRM_PURCHASE_NONREFUNDABLE_ITEM"].OnAccept = ConfirmPopup_OnAccept

---@param self MerchantItemButton
local function MerchantItemButton_OnModifiedClick_Hook(self, _)
	if self.hasStackSplit == 1 then
		if StackSplitFrame.UpdateStackSplitFrame then
			StackSplitFrame:UpdateStackSplitFrame(MAX_STACK)
		else
			UpdateStackSplitFrame(MAX_STACK)
		end

		StackSplitFrame.BulkBuy_stackCount = StackSplitFrame.minSplit
		StackSplitFrame.minSplit = 1
	elseif MerchantFrame.selectedTab == 1 and IsModifiedClick("SPLITSTACK") then
		local info = C_MerchantFrame_GetItemInfo(self:GetID())
		if info.stackCount > 1 and info.hasExtendedCost then return end

		StackSplitFrame:OpenStackSplitFrame(MAX_STACK, self, "BOTTOMLEFT", "TOPLEFT", info.stackCount)
	end
end

hooksecurefunc("MerchantItemButton_OnModifiedClick", MerchantItemButton_OnModifiedClick_Hook)

if StackSplitMixin then
	local StackSplitMixinHooks = {}

	function StackSplitMixinHooks:OpenStackSplitFrame()
		self.BulkBuy_stackCount = nil
	end

	function StackSplitMixinHooks:UpdateStackText()
		if self.isMultiStack and self.BulkBuy_stackCount then
			self.StackSplitText:SetText(STACKS:format(math.ceil(self.split / self.BulkBuy_stackCount)))
		end
	end

	for name, method in pairs(StackSplitMixinHooks) do
		hooksecurefunc(StackSplitFrame, name, method)
	end
else
	hooksecurefunc("OpenStackSplitFrame", function()
		StackSplitFrame.BulkBuy_stackCount = nil
	end)

	hooksecurefunc("UpdateStackSplitFrame", function()
		if StackSplitFrame.isMultiStack and StackSplitFrame.BulkBuy_stackCount then
			StackSplitText:SetText(STACKS:format(math.ceil(StackSplitFrame.split / StackSplitFrame.BulkBuy_stackCount)))
		end
	end)
end

local StackSplitFrame_UpdateStackText

if StackSplitFrame.UpdateStackText then
	StackSplitFrame_UpdateStackText = function()
		StackSplitFrame:UpdateStackText()
	end
else
	StackSplitFrame_UpdateStackText = function()
		StackSplitText:SetText(tostring(StackSplitFrame.split));
	end
end

local StackSplitFrame_LeftButton = StackSplitFrame.LeftButton or StackSplitLeftButton
local StackSplitFrame_RightButton = StackSplitFrame.RightButton or StackSplitRightButton

local function StackSplitFrame_LeftButton_OnClick()
	if StackSplitFrame.split == StackSplitFrame.minSplit then
		return
	end

	-- If the Split Stack modifier is held, decrement by the stackCount; else decrement by minSplit
	StackSplitFrame.split = StackSplitFrame.split -
		(IsModifiedClick("SPLITSTACK") and StackSplitFrame.BulkBuy_stackCount or StackSplitFrame.minSplit)
	StackSplitFrame.split = math.max(StackSplitFrame.split, StackSplitFrame.minSplit)
	StackSplitFrame_UpdateStackText()

	if StackSplitFrame.split == StackSplitFrame.minSplit then
		StackSplitFrame_LeftButton:Disable()
	end

	StackSplitFrame_RightButton:Enable()
end

StackSplitFrame_LeftButton:SetScript("OnClick", StackSplitFrame_LeftButton_OnClick)

local function StackSplitFrame_RightButton_OnClick()
	if StackSplitFrame.split == StackSplitFrame.maxStack then
		return
	end

	-- If the Split Stack modifier is held, increment by stackCount; else increment by minSplit
	StackSplitFrame.split = StackSplitFrame.split +
		(IsModifiedClick("SPLITSTACK") and StackSplitFrame.BulkBuy_stackCount or StackSplitFrame.minSplit)
	StackSplitFrame.split = math.min(StackSplitFrame.split, StackSplitFrame.maxStack)
	StackSplitFrame_UpdateStackText()

	if StackSplitFrame.split == StackSplitFrame.maxStack then
		StackSplitFrame_RightButton:Disable()
	end

	StackSplitFrame_LeftButton:Enable()
end

StackSplitFrame_RightButton:SetScript("OnClick", StackSplitFrame_RightButton_OnClick)
