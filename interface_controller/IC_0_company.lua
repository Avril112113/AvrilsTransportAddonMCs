require("interface_controller.base")

INTERFACE.viewIndex = 0
INTERFACE.viewName = "Company"

---@class CompanyData
EMPTY_COMPANY_DATA = {
	name="NO_COMPANY",
	money=9999999.99,
	---@type table<string, true>
	licences={},
}
companyData = EMPTY_COMPANY_DATA


-- UPDATE_COMPANY
Binnet:registerPacketReader(1, function(binnet, reader)
	if #reader <= 0 then
		companyData = EMPTY_COMPANY_DATA
		viewIndexOut = INTERFACE.viewIndex
		return
	end
	local name = reader:readString()
	if name ~= companyData.name then
		viewIndexOut = INTERFACE.viewIndex
	end
	companyData = {
		name=name,
		money=reader:readCustom(-(2^24), 2^24, 0.01),
		licences={},
	}
	for i=1,reader:readUByte() do
		companyData.licences[reader:readString()] = true
	end
end)


function viewReset()
	companyData = EMPTY_COMPANY_DATA
end

function viewTick()
end

function viewDraw()
	screen.drawText(1, 11, ("Name: %s\nMoney: $%.2f"):format(
		companyData.name,
		companyData.money
	))
end
