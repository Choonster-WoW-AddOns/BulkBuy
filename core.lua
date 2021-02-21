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

-- @debug@
local function log(func, message, ...)
	print("BulkBuy", func, message:format(...))
end

local function concat(...)
	return (" "):join(tostringall(...))
end
-- @end-debug@

--[===[@non-debug@
local function log()
end

local function concat()
end
--@end-non-debug@]===]

local _BuyMerchantItem

local function SetBuyMerchantItem()
	log("SetBuyMerchantItem", "Current value = %s", _BuyMerchantItem)

	_BuyMerchantItem = _G.BuyMerchantItem

	log("SetBuyMerchantItem", "New value = %s", _BuyMerchantItem)
end

local function BulkBuyMerchantItem(slot, amount)
	local stackSize = GetMerchantItemMaxStack(slot)
	local name, texture, price, stackCount, numAvailable, isPurchasable, isUsable, extendedCost, currencyID, spellID = GetMerchantItemInfo(slot)

	log("BulkBuyMerchantItem", "GetMerchantItemMaxStack = %d, GetMerchantItemInfo = %s", stackSize, concat(GetMerchantItemInfo(slot)))

	-- If the item is sold for a non-gold currency and can only be bought in stacks of `stackCount`, buy the largest multiple of `stackCount` less than `amount` possible.
	if price <= 0 then
		amount = math.floor(amount / stackCount) * stackCount

		log("BulkBuyMerchantItem", "price <= 0, new amount = %d", amount)
	end

	-- Otherwise the item is sold for gold, so buy `amount` items

	while amount > stackSize do -- Buy as many full stacks as we can
		log("BulkBuyMerchantItem", "Buying full stacks - amount = %d, stackSize = %d", amount, stackSize)

		_BuyMerchantItem(slot, stackSize)
		amount = amount - stackSize
	end

	if amount > 0 then -- Buy any leftover items
		log("BulkBuyMerchantItem", "Buying leftover items - amount = %d", amount)

		_BuyMerchantItem(slot, amount)
	end
end

-- Wrapper around the default MerchantFrame_ConfirmExtendedItemCost function that temporarily replaces BuyMerchantItem with BulkBuyMerchantItem
local function MerchantFrame_ConfirmExtendedBulkItemCost(itemButton, numToPurchase)
	SetBuyMerchantItem()

	log("MerchantFrame_ConfirmExtendedBulkItemCost", "Replacing _G.BuyMerchantItem with BulkBuyMerchantItem")
	_G.BuyMerchantItem = BulkBuyMerchantItem

	log("MerchantFrame_ConfirmExtendedBulkItemCost", "Calling MerchantFrame_ConfirmExtendedItemCost(%s, %d)", itemButton.GetName and itemButton:GetName() or itemButton, numToPurchase)
	MerchantFrame_ConfirmExtendedItemCost(itemButton, numToPurchase)

	log("MerchantFrame_ConfirmExtendedBulkItemCost", "Restoring _G.BuyMerchantItem")
	_G.BuyMerchantItem = _BuyMerchantItem
end

local function MerchantItemButton_SplitStack(self, split)
	if self.extendedCost then
		log("MerchantItemButton_SplitStack", "Has extended cost, split = %d", split)

		MerchantFrame_ConfirmExtendedBulkItemCost(self, split)
	elseif split > 0 then
		log("MerchantItemButton_SplitStack", "No extended cost, split = %d", split)

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
	log("ConfirmPopup_OnAccept", "itemIndex = %d, count = %d", itemIndex, count)

	SetBuyMerchantItem()
	BulkBuyMerchantItem(MerchantFrame.itemIndex, MerchantFrame.count or 1)
end

StaticPopupDialogs["CONFIRM_PURCHASE_TOKEN_ITEM"].OnAccept = ConfirmPopup_OnAccept
StaticPopupDialogs["CONFIRM_PURCHASE_NONREFUNDABLE_ITEM"].OnAccept = ConfirmPopup_OnAccept

local function MerchantItemButton_OnModifiedClick_Hook(self, button)
	if self.hasStackSplit == 1 then
		log("MerchantItemButton_OnModifiedClick_Hook", "Has split stack, minSplit = %d", StackSplitFrame.minSplit)

		StackSplitFrame:UpdateStackSplitFrame(MAX_STACK)
		StackSplitFrame.BulkBuy_stackCount = StackSplitFrame.minSplit
		StackSplitFrame.minSplit = 1
	elseif MerchantFrame.selectedTab == 1 and IsModifiedClick("SPLITSTACK") then
		local _, _, _, stackCount, _, _, _, extendedCost = GetMerchantItemInfo(self:GetID())

		log("MerchantItemButton_OnModifiedClick_Hook", "On merchant tab and click is SPLITSTACK, stackCount = %d, extendedCost = %s", stackCount, extendedCost)

		if stackCount > 1 and extendedCost then return end

		log("MerchantItemButton_OnModifiedClick_Hook", "Opening stack split frame")

		StackSplitFrame:OpenStackSplitFrame(MAX_STACK, self, "BOTTOMLEFT", "TOPLEFT", stackCount)
	end
end

hooksecurefunc("MerchantItemButton_OnModifiedClick", MerchantItemButton_OnModifiedClick_Hook)

local StackSplitMixinHooks = {}

function StackSplitMixinHooks:OpenStackSplitFrame()
	log("StackSplitMixinHooks:OpenStackSplitFrame", "Clearing BulkBuy_stackCount, current value = %s", tostring(self.BulkBuy_stackCount))

	self.BulkBuy_stackCount = nil
end

function StackSplitMixinHooks:UpdateStackText()
	if self.isMultiStack and self.BulkBuy_stackCount then
		local originalText = self.StackSplitText:GetText()

		self.StackSplitText:SetText(STACKS:format(math.ceil(self.split / self.BulkBuy_stackCount)))

		log("StackSplitMixinHooks:UpdateStackText", "isMultiStack and has BulkBuy_stackCount, original text = %s, new text = %s", originalText, self.StackSplitText:GetText())
	end
end

for name, method in pairs(StackSplitMixinHooks) do
	hooksecurefunc(StackSplitFrame, name, method)
end

local function StackSplitLeftButton_OnClick()
	if StackSplitFrame.split == StackSplitFrame.minSplit then
		log("StackSplitLeftButton_OnClick", "split == minSplit, ignoring")
		return
	end

	-- If the Split Stack modifier is held, decrement by the stackCount; else decrement by minSplit
	local originalAmount = StackSplitFrame.split
	local decrementAmount = IsModifiedClick("SPLITSTACK") and StackSplitFrame.BulkBuy_stackCount or StackSplitFrame.minSplit

	StackSplitFrame.split = StackSplitFrame.split - decrementAmount
	StackSplitFrame.split = math.max(StackSplitFrame.split, StackSplitFrame.minSplit)
	StackSplitFrame:UpdateStackText()

	log("StackSplitLeftButton_OnClick", "Original amount = %d, decrementing by %d", originalAmount, decrementAmount)

	if StackSplitFrame.split == StackSplitFrame.minSplit then
		log("StackSplitLeftButton_OnClick", "split == minSplit, disabling left button")

		StackSplitFrame.LeftButton:Disable()
	end

	StackSplitFrame.RightButton:Enable()
end

StackSplitFrame.LeftButton:SetScript("OnClick", StackSplitLeftButton_OnClick)

local function StackSplitRightButton_OnClick()
	if StackSplitFrame.split == StackSplitFrame.maxStack then
		log("StackSplitRightButton_OnClick", "split == maxStack, ignoring")
		return
	end

	-- If the Split Stack modifier is held, increment by stackCount; else increment by minSplit
	local originalAmount = StackSplitFrame.split
	local incrementAmount = IsModifiedClick("SPLITSTACK") and StackSplitFrame.BulkBuy_stackCount or StackSplitFrame.minSplit

	StackSplitFrame.split = StackSplitFrame.split + incrementAmount
	StackSplitFrame.split = math.min(StackSplitFrame.split, StackSplitFrame.maxStack)
	StackSplitFrame:UpdateStackText()

	log("StackSplitRightButton_OnClick", "Original amount = %d, incrementing by %d", originalAmount, incrementAmount)

	if StackSplitFrame.split == StackSplitFrame.maxStack then
		log("StackSplitRightButton_OnClick", "split == maxStack, disabling right button")

		StackSplitFrame.RightButton:Disable()
	end

	StackSplitFrame.LeftButton:Enable()
end

StackSplitFrame.RightButton:SetScript("OnClick", StackSplitRightButton_OnClick)
