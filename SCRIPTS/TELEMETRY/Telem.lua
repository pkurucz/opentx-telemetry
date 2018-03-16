--[[
               OpenTX Telemetry Script for Taranis X9D Plus / X8R
               --------------------------------------------------

                       Alexander Koch <lynix47@gmail.com>

             Based on 'olimetry.lua' by Ollicious <bowdown@gmx.net>

                    Adapted for dRonin by <yds@Necessitu.de>
--]]


-- settings  -------------------------------------------------------------------

local srcAltd = "GAlt"	-- "Alt" for barometric or "GAlt" GPS altitude
local srcLink = "RSSI"	-- "RSSI" or "LQ" for Crossfire
local widgets = {
                  {"battery"},
                  {"gps", "alt", "speed"},
                  {"mode", "dist", "timer"},
                  {"rssi"}
                }
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

    local link = getValue(srcLink)
    local percent = 0

    if link > 38 then
        percent = (math.log(link-28, 10) - 1) / (math.log(72, 10) - 1) * 100
    end

    local pixmap = "/IMAGES/TELEM/RSSIh00.bmp"
    if     percent > 90 then pixmap = "/IMAGES/TELEM/RSSIh10.bmp"
    elseif percent > 80 then pixmap = "/IMAGES/TELEM/RSSIh09.bmp"
    elseif percent > 70 then pixmap = "/IMAGES/TELEM/RSSIh08.bmp"
    elseif percent > 60 then pixmap = "/IMAGES/TELEM/RSSIh07.bmp"
    elseif percent > 50 then pixmap = "/IMAGES/TELEM/RSSIh06.bmp"
    elseif percent > 40 then pixmap = "/IMAGES/TELEM/RSSIh05.bmp"
    elseif percent > 30 then pixmap = "/IMAGES/TELEM/RSSIh04.bmp"
    elseif percent > 20 then pixmap = "/IMAGES/TELEM/RSSIh03.bmp"
    elseif percent > 10 then pixmap = "/IMAGES/TELEM/RSSIh02.bmp"
    elseif percent > 0  then pixmap = "/IMAGES/TELEM/RSSIh01.bmp"
    end

    lcd.drawPixmap(x+4, y+1, pixmap)
    lcd.drawText(x+6, y+54, link .. "dB", 0)

end


local function distWidget(x, y)

    local dist = getValue("Dist")

    lcd.drawPixmap(x+1, y+2, "/IMAGES/TELEM/dist.bmp")
    lcd.drawNumber(x+18, y+7, dist, LEFT)
    lcd.drawText(lcd.getLastPos(), y+7, "m", 0)

end


local function altitudeWidget(x, y)

    local altitude = getValue(srcAltd)

    lcd.drawPixmap(x+1, y+2, "/IMAGES/TELEM/hgt.bmp")
    lcd.drawNumber(x+18, y+7, altitude, LEFT)
    lcd.drawText(lcd.getLastPos(), y+7, "m", 0)

end


local function speedWidget(x, y)

    local speed = getValue("GSpd") * 3.6

    lcd.drawPixmap(x+1, y+2, "/IMAGES/TELEM/speed.bmp")
    lcd.drawNumber(x+18, y+7, speed, LEFT)
    lcd.drawText(lcd.getLastPos(), y+7, "kmh", 0)

end


local function headingWidget(x, y)

    local heading = getValue("Hdg")

    lcd.drawPixmap(x+1, y+2, "/IMAGES/TELEM/compass.bmp")
    lcd.drawNumber(x+18, y+7, heading, LEFT)
    lcd.drawText(lcd.getLastPos(), y+7, "dg", 0)

end


local function modeWidget(x, y)

    local style = MIDSIZE
    local mode = getValue("RPM")
    local armed = math.floor(mode * 0.01) == 1
    local sound

    mode = math.floor(mode % 100)
  
    if     mode ==  0 then mode = "Manual";	sound = "fm-manl"
    elseif mode ==  1 then mode = "Acro";	sound = "fm-acr"
    elseif mode ==  2 then mode = "Level";	sound = "fm-lvl"
    elseif mode ==  3 then mode = "Horizon";	sound = "fm-hrzn"
    elseif mode ==  4 then mode = "AxisLck";	sound = "fm-axlk"
    elseif mode ==  5 then mode = "VirtBar";	sound = "fm-vbar"
    elseif mode ==  6 then mode = "Stabil1";	sound = "fm-stbl"
    elseif mode ==  7 then mode = "Stabil2";	sound = "fm-stbl"
    elseif mode ==  8 then mode = "Stabil3";	sound = "fm-stbl"
    elseif mode ==  9 then mode = "Tune";	sound = "fm-tune";	style = style + BLINK
    elseif mode == 10 then mode = "AltHold";	sound = "fm-ahld"
    elseif mode == 11 then mode = "PosHold";	sound = "fm-phld"
    elseif mode == 12 then mode = "RToHome";	sound = "fm-rth"
    elseif mode == 13 then mode = "PathPln";	sound = "fm-plan"
    elseif mode == 15 then mode = "Acro+";	sound = "fm-acr"
    elseif mode == 16 then mode = "AcrDyn";	sound = "fm-acr"
    elseif mode == 17 then mode = "Fail";	sound = "fm-fail";	style = style + BLINK
    end

    lcd.drawPixmap(x+1, y+2, "/IMAGES/TELEM/fm.bmp")
    lcd.drawText(x+20, y+4, mode, style)
    playFile(sound)

end


local function timerWidget(x, y)

    lcd.drawPixmap(x+1, y+3, "/IMAGES/TELEM/timer_1.bmp")
    lcd.drawTimer(x+18, y+8, getValue(196), 0)

end


local function gpsWidget(x,y)

    local sats = getValue("Sats")
    local fix  = getValue("Fix")

    local fixImg = "/IMAGES/TELEM/sat0.bmp"
    if     fix == 2 then fixImg = "/IMAGES/TELEM/sat1.bmp"
    elseif fix == 3 then fixImg = "/IMAGES/TELEM/sat2.bmp"
    elseif fix == 4 then fixImg = "/IMAGES/TELEM/sat3.bmp"
    end

    local satImg = "/IMAGES/TELEM/gps_0.bmp"
    if     sats > 5 then satImg = "/IMAGES/TELEM/gps_6.bmp"
    elseif sats > 4 then satImg = "/IMAGES/TELEM/gps_5.bmp"
    elseif sats > 3 then satImg = "/IMAGES/TELEM/gps_4.bmp"
    elseif sats > 2 then satImg = "/IMAGES/TELEM/gps_3.bmp"
    elseif sats > 1 then satImg = "/IMAGES/TELEM/gps_2.bmp"
    elseif sats > 0 then satImg = "/IMAGES/TELEM/gps_1.bmp"
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
