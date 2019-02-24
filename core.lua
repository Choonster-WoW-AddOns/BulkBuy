local MAX_STACK = 10000 -- The maximum stack size accepted by the stack split frame.

-----------------
--END OF CONFIG--
-----------------

-- List globals here for Mikk's FindGlobals script.
--
-- FrameXML frames and functions:
-- GLOBALS: MerchantFrame, MerchantFrame_ConfirmExtendedItemCost, StackSplitFrame
--
-- WoW API functions:
-- GLOBALS: BuyMerchantItem, GetMerchantItemInfo, GetMerchantItemMaxStack, IsModifiedClick
--
-- Global strings:
-- GLOBALS: STACKS
--
-- Lua libraries:
-- GLOBALS: math

local _BuyMerchantItem

local function SetBuyMerchantItem()
	_BuyMerchantItem = _G.BuyMerchantItem
end

local function BulkBuyMerchantItem(slot, amount)
	local stackSize = GetMerchantItemMaxStack(slot)
	local name, texture, price, stackCount, numAvailable, isPurchasable, isUsable, extendedCost = GetMerchantItemInfo(slot)
	
	-- If the item is sold for a non-gold currency and can only be bought in stacks of `stackCount`, buy the largest multiple of `stackCount` less than `amount` possible.
	if price <= 0 then 
		amount = math.floor(amount / stackCount) * stackCount
	end
	
	-- Otherwise the item is sold for gold, so buy `amount` items
	
	while amount > stackSize do -- Buy as many full stacks as we can
		_BuyMerchantItem(slot, stackSize)
		amount = amount - stackSize
	end
		
	if amount > 0 then -- Buy any leftover items
		_BuyMerchantItem(slot, amount)
	end
end

-- Wrapper around the default MerchantFrame_ConfirmExtendedItemCost function that temporarily replaces BuyMerchantItem with BulkBuyMerchantItem
local function MerchantFrame_ConfirmExtendedBulkItemCost(itemButton, numToPurchase)
	SetBuyMerchantItem()
	_G.BuyMerchantItem = BulkBuyMerchantItem
	MerchantFrame_ConfirmExtendedItemCost(itemButton, numToPurchase)
	_G.BuyMerchantItem = _BuyMerchantItem
end

local function MerchantItemButton_SplitStack(self, split)
	if self.extendedCost then
		MerchantFrame_ConfirmExtendedBulkItemCost(self, split)
	elseif split > 0 then
		SetBuyMerchantItem()
		BulkBuyMerchantItem(self:GetID(), split)
	end
end

-- Overwrite the default UI's SplitStack method
-- There are 12 MerchantItemXItemButtons, but the merchant frame only uses the first 10; the others are only used by the buyback window
for i = 1, 10 do
	local button = _G["MerchantItem".. i .."ItemButton"]
	button.SplitStack = MerchantItemButton_SplitStack
end

local function ConfirmPopup_OnAccept()
	SetBuyMerchantItem()
	BulkBuyMerchantItem(MerchantFrame.itemIndex, MerchantFrame.count or 1)
end

StaticPopupDialogs["CONFIRM_PURCHASE_TOKEN_ITEM"].OnAccept = ConfirmPopup_OnAccept
StaticPopupDialogs["CONFIRM_PURCHASE_NONREFUNDABLE_ITEM"].OnAccept = ConfirmPopup_OnAccept

local function MerchantItemButton_OnModifiedClick_Hook(self, button)
	if self.hasStackSplit == 1 then
		StackSplitFrame:UpdateStackSplitFrame(MAX_STACK)
		StackSplitFrame.BulkBuy_stackCount = StackSplitFrame.minSplit
		StackSplitFrame.minSplit = 1
	elseif MerchantFrame.selectedTab == 1 and IsModifiedClick("SPLITSTACK") then
		local _, _, _, stackCount, _, _, _, extendedCost = GetMerchantItemInfo(self:GetID())
		if stackCount > 1 and extendedCost then return end
		
		StackSplitFrame:OpenStackSplitFrame(MAX_STACK, self, "BOTTOMLEFT", "TOPLEFT", stackCount)
	end
end

hooksecurefunc("MerchantItemButton_OnModifiedClick", MerchantItemButton_OnModifiedClick_Hook)

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

local function StackSplitLeftButton_OnClick()
	if StackSplitFrame.split == StackSplitFrame.minSplit then
		return
	end

	-- If the Split Stack modifier is held, decrement by the stackCount; else decrement by minSplit
	StackSplitFrame.split = StackSplitFrame.split - (IsModifiedClick("SPLITSTACK") and StackSplitFrame.BulkBuy_stackCount or StackSplitFrame.minSplit)
	StackSplitFrame.split = math.max(StackSplitFrame.split, StackSplitFrame.minSplit)
	StackSplitFrame:UpdateStackText()

	if StackSplitFrame.split == StackSplitFrame.minSplit then
		StackSplitFrame.LeftButton:Disable()
	end
	
	StackSplitFrame.RightButton:Enable()
end

StackSplitFrame.LeftButton:SetScript("OnClick", StackSplitLeftButton_OnClick)

local function StackSplitRightButton_OnClick()
	if StackSplitFrame.split == StackSplitFrame.maxStack then
		return
	end

	-- If the Split Stack modifier is held, increment by stackCount; else increment by minSplit
	StackSplitFrame.split = StackSplitFrame.split + (IsModifiedClick("SPLITSTACK") and StackSplitFrame.BulkBuy_stackCount or StackSplitFrame.minSplit)
	StackSplitFrame.split = math.min(StackSplitFrame.split, StackSplitFrame.maxStack)
	StackSplitFrame:UpdateStackText()

	if StackSplitFrame.split == StackSplitFrame.maxStack then
		StackSplitFrame.RightButton:Disable()
	end
	
	StackSplitFrame.LeftButton:Enable()
end

StackSplitFrame.RightButton:SetScript("OnClick", StackSplitRightButton_OnClick)