require("interfaces.base")

INTERFACE.viewIndex = 1
INTERFACE.viewName = "Test 1"

function viewReset()
	temp = false
end

function viewTick()
	if tick % 60 == 0 then
		temp = not temp
	end
	INTERFACE.scroll = temp and 3 or 0
end

function viewDraw()
end
