local MAX_STACK = 10000 -- The maximum stack size accepted by the stack split frame.

-----------------
--END OF CONFIG--
-----------------

-- List globals here for Mikk's FindGlobals script.
--
-- FrameXML frames and functions:
-- GLOBALS: MerchantFrame, MerchantFrame_ConfirmExtendedItemCost, StackSplitFrame, UpdateStackSplitFrame, OpenStackSplitFrame
--
-- WoW API functions:
-- GLOBALS: BuyMerchantItem, GetMerchantItemInfo, GetMerchantItemMaxStack, IsModifiedClick
--
-- Lua libraries:
-- GLOBALS: math

local function BulkBuyMerchantItem(slot, amount)
	local stackSize = GetMerchantItemMaxStack(slot)
	local name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(slot)
	
	if price > 0 then -- Item is sold for gold, buy `amount` items
		while amount > stackSize do -- Buy as many full stacks as we can
			BuyMerchantItem(slot, stackSize)
			amount = amount - stackSize
		end
		
		if amount > 0 then -- Buy any leftover items
			BuyMerchantItem(slot, amount)
		end
	else -- Item is sold for a non-gold currency and can only be bought in stacks of `quantity`, buy `amount * quantity` items
		BuyMerchantItem(slot, amount * quantity)
	end
end

-- Wrapper around the default MerchantFrame_ConfirmExtendedItemCost function that temporarily replaces BuyMerchantItem with BulkBuyMerchantItem
local function MerchantFrame_ConfirmExtendedBulkItemCost(itemButton, numToPurchase)
	local originalBuyMerchantItem = BuyMerchantItem
	BuyMerchantItem = BulkBuyMerchantItem
	MerchantFrame_ConfirmExtendedItemCost(itemButton, numToPurchase)
	BuyMerchantItem = originalBuyMerchantItem
end

local function MerchantItemButton_SplitStack(self, split)
	if self.extendedCost then
		MerchantFrame_ConfirmExtendedBulkItemCost(self, split)
	elseif split > 0 then
		BulkBuyMerchantItem(self:GetID(), split)
	end
end

-- Overwrite the default UI's SplitStack method
-- There are 12 MerchantItemXItemButtons, but the merchant frame only uses the first 10; the others are only used by the buyback window
for i = 1, 10 do
	local button = _G["MerchantItem".. i .."ItemButton"]
	button.SplitStack = MerchantItemButton_SplitStack
end

StaticPopupDialogs["CONFIRM_PURCHASE_TOKEN_ITEM"].OnAccept = function()
	BulkBuyMerchantItem(MerchantFrame.itemIndex, MerchantFrame.count or 1)
end

local function MerchantItemButton_OnModifiedClick_Hook(self, button)
	if self.hasStackSplit == 1 then
		UpdateStackSplitFrame(MAX_STACK)
	elseif MerchantFrame.selectedTab == 1 and IsModifiedClick("SPLITSTACK") then
		local _, _, _, stackCount, _, _, extendedCost = GetMerchantItemInfo(self:GetID())
		if stackCount > 1 and extendedCost then return end
		
		OpenStackSplitFrame(MAX_STACK, self, "BOTTOMLEFT", "TOPLEFT")
	end
end

hooksecurefunc("MerchantItemButton_OnModifiedClick", MerchantItemButton_OnModifiedClick_Hook)