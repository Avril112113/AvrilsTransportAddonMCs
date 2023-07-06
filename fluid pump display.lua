--- This is not built with LifeBoatAPI.


local FLUID_TYPE_TO_NAME = {
	[-1]="~~~~~~",
	[0]="fresh water",
	[1]="diesel",
	[2]="jetfuel",
	[3]="air",
	[4]="exhaust",
	[5]="oil",
	[6]="seawater",
	[7]="steam",
	[8]="slurry",
	[9]="slurry saturated",
}


local fluid_type = 0
local fluid_amount = 0
local fluid_cost = 0
local fluid_worth = 0
function onTick()
	fluid_type = input.getNumber(1)-1
	fluid_amount = input.getNumber(2)
	fluid_cost = input.getNumber(3)
	fluid_worth = input.getNumber(4)
end


function onDraw()
	screen.drawText(0, 0, (" %s\nbuy $%.2f/l\nsel $%.2f/l\n %+.1fl\n$%+.2f"):format(
		FLUID_TYPE_TO_NAME[fluid_type],
		fluid_cost,
		fluid_worth,
		fluid_amount,
		fluid_amount > 0 and -fluid_amount*fluid_cost or -fluid_amount*fluid_worth
	))
end
