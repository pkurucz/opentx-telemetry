--[[
               OpenTX Telemetry Script for Taranis X9D Plus / X8R
               --------------------------------------------------

                       Alexander Koch <lynix47@gmail.com>

             Based on 'olimetry.lua' by Ollicious <bowdown@gmx.net>

	            Adapted for dRonin by <yds@Necessitu.de>
--]]


-- settings  -------------------------------------------------------------------

local widgets  = { {"battery"},
                   {"gps", "alt", "speed"},
                   {"mode", "dist", "timer"},
                   {"rssi"} }
local cellMaxV = 4.20
local cellMinV = 3.60


-- globals  --------------------------------------------------------------------

local displayWidth	= 212
local displayHeight	= 64
local widgetWidthSingle	= 35
local widgetWidthMulti	= 0
local battCellRange	= cellMaxV - cellMinV
local widget		= {}


-- widget functions  -----------------------------------------------------------

local function batteryWidget(x, y)

    lcd.drawFilledRectangle(x+13, y+7, 5, 2, 0)
    lcd.drawRectangle(x+10, y+9, 11, 40)

    local cellVolt = getValue("Cels")

    local availV = 0
    if cellVolt > cellMaxV then
        availV = battCellRange
    elseif cellVolt > cellMinV then
        availV = cellVolt - cellMinV
    end
    local availPerc = math.floor(availV / battCellRange * 100)

    local myPxHeight = math.floor(availPerc * 0.37)
    local myPxY = 11 + 37 - myPxHeight
    if availPerc > 0 then
        lcd.drawFilledRectangle(x+11, myPxY, 9, myPxHeight, 0)
    end

    local i = 36
    while (i > 0) do
        lcd.drawLine(x+12, y+10+i, x+18, y+10+i, SOLID, GREY_DEFAULT)
        i = i-2
    end

    local style = PREC2 + LEFT
    if cellVolt < cellMinV then
        style = style + BLINK
    end
    lcd.drawNumber(x+5, y+54, cellVolt*100, style)
    lcd.drawText(lcd.getLastPos(), y+54, "V", 0)

end


local function rssiWidget(x, y)

    local db = getValue("RSSI")
    local percent = 0

    if db > 38 then
        percent = (math.log(db-28, 10) - 1) / (math.log(72, 10) - 1) * 100
    end

    local pixmap = "/SCRIPTS/TELEMETRY/GFX/RSSIh00.bmp"
    if     percent > 90 then pixmap = "/SCRIPTS/TELEMETRY/GFX/RSSIh10.bmp"
    elseif percent > 80 then pixmap = "/SCRIPTS/TELEMETRY/GFX/RSSIh09.bmp"
    elseif percent > 70 then pixmap = "/SCRIPTS/TELEMETRY/GFX/RSSIh08.bmp"
    elseif percent > 60 then pixmap = "/SCRIPTS/TELEMETRY/GFX/RSSIh07.bmp"
    elseif percent > 50 then pixmap = "/SCRIPTS/TELEMETRY/GFX/RSSIh06.bmp"
    elseif percent > 40 then pixmap = "/SCRIPTS/TELEMETRY/GFX/RSSIh05.bmp"
    elseif percent > 30 then pixmap = "/SCRIPTS/TELEMETRY/GFX/RSSIh04.bmp"
    elseif percent > 20 then pixmap = "/SCRIPTS/TELEMETRY/GFX/RSSIh03.bmp"
    elseif percent > 10 then pixmap = "/SCRIPTS/TELEMETRY/GFX/RSSIh02.bmp"
    elseif percent > 0  then pixmap = "/SCRIPTS/TELEMETRY/GFX/RSSIh01.bmp"
    end

    lcd.drawPixmap(x+4, y+1, pixmap)
    lcd.drawText(x+6, y+54, db .. "dB", 0)

end


local function distWidget(x, y)

    local dist = getValue("Dist")

    lcd.drawPixmap(x+1, y+2, "/SCRIPTS/TELEMETRY/GFX/dist.bmp")
    lcd.drawNumber(x+18, y+7, dist, LEFT)
    lcd.drawText(lcd.getLastPos(), y+7, "m", 0)

end


local function altitudeWidget(x, y)

    local height = getValue("GAlt")

    lcd.drawPixmap(x+1, y+2, "/SCRIPTS/TELEMETRY/GFX/hgt.bmp")
    lcd.drawNumber(x+18, y+7, height, LEFT)
    lcd.drawText(lcd.getLastPos(), y+7, "m", 0)

end


local function speedWidget(x, y)

    local speed = getValue("GSpd") * 3.6

    lcd.drawPixmap(x+1, y+2, "/SCRIPTS/TELEMETRY/GFX/speed.bmp")
    lcd.drawNumber(x+18, y+7, speed, LEFT)
    lcd.drawText(lcd.getLastPos(), y+7, "kmh", 0)

end


local function headingWidget(x, y)

    local heading = getValue("Hdg")

    lcd.drawPixmap(x+1, y+2, "/SCRIPTS/TELEMETRY/GFX/compass.bmp")
    lcd.drawNumber(x+18, y+7, heading, LEFT)
    lcd.drawText(lcd.getLastPos(), y+7, "dg", 0)

end


local function modeWidget(x, y)

    local style = MIDSIZE
    local mode = getValue("RPM")
    local armed = math.floor(mode * 0.01) == 1

    mode = math.floor(mode % 100)
  
    if     mode ==  0 then mode = "Manual"
    elseif mode ==  1 then mode = "Acro"
    elseif mode ==  2 then mode = "Level"
    elseif mode ==  3 then mode = "Horizon"
    elseif mode ==  4 then mode = "AxisLck"
    elseif mode ==  5 then mode = "VirtBar"
    elseif mode ==  6 then mode = "Stabil1"
    elseif mode ==  7 then mode = "Stabil2"
    elseif mode ==  8 then mode = "Stabil3"
    elseif mode ==  9 then mode = "Tune";	style = style + BLINK
    elseif mode == 10 then mode = "AltHold"
    elseif mode == 11 then mode = "PosHold"
    elseif mode == 12 then mode = "RToHome"
    elseif mode == 13 then mode = "PathPln"
    elseif mode == 15 then mode = "Acro+"
    elseif mode == 16 then mode = "AcrDyn"
    elseif mode == 17 then mode = "Fail";	style = style + BLINK
    end

    lcd.drawPixmap(x+1, y+2, "/SCRIPTS/TELEMETRY/GFX/fm.bmp")
    lcd.drawText(x+20, y+4, mode, style)

end


local function timerWidget(x, y)

    lcd.drawPixmap(x+1, y+3, "/SCRIPTS/TELEMETRY/GFX/timer_1.bmp")
    lcd.drawTimer(x+18, y+8, getValue(196), 0)

end


local function gpsWidget(x,y)

    local sats = getValue("Sats")
    local fix  = getValue("Fix")

    local fixImg = "/SCRIPTS/TELEMETRY/GFX/sat0.bmp"
    if     fix == 2 then fixImg = "/SCRIPTS/TELEMETRY/GFX/sat1.bmp"
    elseif fix == 3 then fixImg = "/SCRIPTS/TELEMETRY/GFX/sat2.bmp"
    elseif fix == 4 then fixImg = "/SCRIPTS/TELEMETRY/GFX/sat3.bmp"
    end

    local satImg = "/SCRIPTS/TELEMETRY/GFX/gps_0.bmp"
    if     sats > 5 then satImg = "/SCRIPTS/TELEMETRY/GFX/gps_6.bmp"
    elseif sats > 4 then satImg = "/SCRIPTS/TELEMETRY/GFX/gps_5.bmp"
    elseif sats > 3 then satImg = "/SCRIPTS/TELEMETRY/GFX/gps_4.bmp"
    elseif sats > 2 then satImg = "/SCRIPTS/TELEMETRY/GFX/gps_3.bmp"
    elseif sats > 1 then satImg = "/SCRIPTS/TELEMETRY/GFX/gps_2.bmp"
    elseif sats > 0 then satImg = "/SCRIPTS/TELEMETRY/GFX/gps_1.bmp"
    end

    lcd.drawPixmap(x+1, y+1, fixImg)
    lcd.drawPixmap(x+13, y+3, satImg)
    lcd.drawNumber(x+19, y+1, sats, SMLSIZE)

 end


-- main logic  -----------------------------------------------------------------

local function run(event)

    lcd.clear()

    local x = -1
    local y = -1
    local c

    for col=1, #widgets, 1 do
        if #widgets[col] == 1 then
            c = widgetWidthSingle
        else
            c = widgetWidthMulti
        end

        for row=1, #widgets[col], 1 do
            lcd.drawLine(x, y, x+c, y, SOLID, GREY_DEFAULT)
            widget[widgets[col][row]](x+1, y+1)
            y = y + math.floor(displayHeight / #widgets[col])
        end

        y = -1
        x = x + c
    end

end


local function init()

    widget["alt"] = altitudeWidget
    widget["battery"] = batteryWidget
    widget["dist"] = distWidget
    widget["mode"] = modeWidget
    widget["gps"] = gpsWidget
    widget["heading"] = headingWidget
    widget["rssi"] = rssiWidget
    widget["speed"] = speedWidget
    widget["timer"] = timerWidget

    local colsSingle = 0
    local colsMulti  = 0
    for i=1, #widgets, 1 do
        if #widgets[i] == 1 then
            colsSingle = colsSingle + 1
        else
            colsMulti = colsMulti + 1
        end
    end

    widgetWidthMulti = (displayWidth - (colsSingle * widgetWidthSingle))
    widgetWidthMulti = widgetWidthMulti / colsMulti

end


-- module definition  ----------------------------------------------------------

return {init=init, run=run}
