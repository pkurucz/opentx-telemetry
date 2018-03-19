--[[
               OpenTX Telemetry Script for Taranis X9D Plus / X8R
               --------------------------------------------------

                       Alexander Koch <lynix47@gmail.com>

             Based on 'olimetry.lua' by Ollicious <bowdown@gmx.net>

                    Adapted for dRonin by <yds@Necessitu.de>
--]]


-- settings  -------------------------------------------------------------------

local Altd	= 'GAlt' -- 'Alt' for barometric or 'GAlt' GPS altitude
local battCells	= 0	-- 5=5S or 7=7S or autodetect 1S, 2S, 3S, 4S, 6S or 8S
local cellMinV	= 3.30	-- minimum voltage alert threshold
local layout	= {	-- screen widgets
                    { 'battery' },
                    { 'gps', 'dist', 'alt' },
                    { 'mode', 'speed', 'timer' },
                    { 'rssi' },
                  }


-- module globals  -------------------------------------------------------------

local fuel		= 0
local linq		= 0
local prevMode		= 0
local dispTime		= 0
local prevTime		= 0
local displayFrame	= 0
local displayWidth	= 212
local displayHeight	= 64
local widgetWidthSingle	= 35
local widgetWidthMulti	= 0
local widget		= {}
local flightMode	= {}

flightMode[-1] = { name = 'NoTelem',				style = BLINK }
flightMode[ 0] = { name = 'Manual',	sound = 'fm-mnl',	style = 0 }
flightMode[ 1] = { name = 'Acro',	sound = 'fm-acr',	style = 0 }
flightMode[ 2] = { name = 'Level',	sound = 'fm-lvl',	style = 0 }
flightMode[ 3] = { name = 'Horizon',	sound = 'fm-hrzn',	style = 0 }
flightMode[ 4] = { name = 'AxisLck',	sound = 'fm-axlk',	style = 0 }
flightMode[ 5] = { name = 'VirtBar',	sound = 'fm-vbar',	style = 0 }
flightMode[ 6] = { name = 'Stabil1',	sound = 'fm-stb1',	style = 0 }
flightMode[ 7] = { name = 'Stabil2',	sound = 'fm-stb2',	style = 0 }
flightMode[ 8] = { name = 'Stabil3',	sound = 'fm-stb3',	style = 0 }
flightMode[ 9] = { name = 'Autotune',	sound = 'fm-tune',	style = BLINK }
flightMode[10] = { name = 'AltHold',	sound = 'fm-ahld',	style = 0 }
flightMode[11] = { name = 'PosHold',	sound = 'fm-phld',	style = 0 }
flightMode[12] = { name = 'RToHome',	sound = 'fm-rth',	style = 0 }
flightMode[13] = { name = 'PathPln',	sound = 'fm-plan',	style = 0 }
flightMode[15] = { name = 'Acro+',	sound = 'fm-acrp',	style = 0 }
flightMode[16] = { name = 'AcroDyne',	sound = 'fm-acrd',	style = 0 }
flightMode[17] = { name = 'FailSafe',	sound = 'fm-fail',	style = BLINK }


-- optimize  -------------------------------------------------------------------

local drawLine = lcd.drawLine
local drawNumber = lcd.drawNumber
local drawPixmap = lcd.drawPixmap
local drawRectangle = lcd.drawRectangle
local drawFilledRectangle = lcd.drawFilledRectangle
local drawText = lcd.drawText
local drawTimer = lcd.drawTimer
local getLastPos = lcd.getLastPos
local getValue = getValue


-- widget functions  -----------------------------------------------------------

local function round(n, p)
    p = 10^(p or 0)
    if n >= 0 then
	return math.floor(n * p + 0.5) / p
    else
	return math.ceil(n * p - 0.5) / p
    end
end


local function batteryWidget(x, y)

    local battVolt = 0
    local cellVolt = getValue('Cels')
    if type(cellVolt) == 'table' then -- FrSky FLVSS
	battCells = 0
	for i, v in ipairs(cellVolt) do
	    battVolt = battVolt + v
	    battCells = battCells + 1
	end
    elseif cellVolt == 0 then
	battVolt = getValue('VFAS')
    else -- dRonin et al
	battVolt = cellVolt
    end

    if battCells ~= 5 or battCells ~= 7 then -- no autodetect for 5S & 7S
        if math.ceil(battVolt / 4.37) > battCells and battVolt < 4.37 * 8 then 
            battCells = math.ceil(battVolt / 4.37)
            if battCells == 7 then battCells = 8 end -- empty 8S looks like 7S
            if battCells == 5 then battCells = 6 end -- empty 6S looks like 5S
        end
    end

    if battCells > 0 then 
        cellVolt = battVolt / battCells 
    end

    local v = 0
    local highVolt = battVolt > 4.22 * battCells
    if highVolt then
	v = cellVolt - 0.15
    else
	v = cellVolt
    end

    if     v >  4.2		then v = 100
    elseif v <  3.2		then v = 0
    elseif v >= 4		then v = 80 * v - 236
    elseif v <= 3.67		then v = 29.787234 * v - 95.319149 
    elseif v >  3.67 and v < 4	then v = 212.53 * v - 765.29
    end

    if linq <= 20 and prevMode == 0 then fuel = 0 end -- No Telemetry

    if fuel == 0 then 
	fuel = round(v) --init percent
    else 
	fuel = round(fuel * 0.98 + 0.02 * v)
    end

    drawNumber(x+10, y, fuel, SMLSIZE)
    drawText(getLastPos(), y, '%', SMLSIZE)

    drawFilledRectangle(x+13, y+9, 5, 2, 0)
    drawRectangle(x+10, y+11, 11, 40)

    local myPxHeight = math.floor(fuel * 0.37)
    local myPxY = 13 + 37 - myPxHeight
    if fuel > 0 then
        drawFilledRectangle(x+11, myPxY, 9, myPxHeight, 0)
    end

    for i=36, 1, -2 do
        drawLine(x+12, y+12+i, x+18, y+12+i, SOLID, GREY_DEFAULT)
    end

    local style = LEFT + PREC2
    if cellVolt < cellMinV then
        style = style + BLINK
    end

    if displayFrame == 0 then
	drawText(x, y+54, battCells..'S ', 0)
	drawNumber(getLastPos(), y+54, cellVolt*100, style)
    elseif displayFrame == 1 then
	drawNumber(x+5, y+54, battVolt*100, style)
	if highVolt then drawText(getLastPos(), y+54, 'H', 0) end
    end
    drawText(getLastPos(), y+54, 'V', 0)

end


local function rssiWidget(x, y)

    linq = getValue('RQly')	-- Crossfire Rx Link Quality
    if linq == 0 then
	linq = getValue('RSSI')	-- FrSky et al
    end
        
    local percent = 0
    if linq > 38 then
        percent = (math.log(linq-28, 10) - 1) / (math.log(72, 10) - 1) * 100
    end

    local pixmap = '/IMAGES/TELEM/RSSIh00.bmp'
    if     percent > 90 then pixmap = '/IMAGES/TELEM/RSSIh10.bmp'
    elseif percent > 80 then pixmap = '/IMAGES/TELEM/RSSIh09.bmp'
    elseif percent > 70 then pixmap = '/IMAGES/TELEM/RSSIh08.bmp'
    elseif percent > 60 then pixmap = '/IMAGES/TELEM/RSSIh07.bmp'
    elseif percent > 50 then pixmap = '/IMAGES/TELEM/RSSIh06.bmp'
    elseif percent > 40 then pixmap = '/IMAGES/TELEM/RSSIh05.bmp'
    elseif percent > 30 then pixmap = '/IMAGES/TELEM/RSSIh04.bmp'
    elseif percent > 20 then pixmap = '/IMAGES/TELEM/RSSIh03.bmp'
    elseif percent > 10 then pixmap = '/IMAGES/TELEM/RSSIh02.bmp'
    elseif percent >  0 then pixmap = '/IMAGES/TELEM/RSSIh01.bmp'
    end

    drawPixmap(x+4, y+3, pixmap)
    drawNumber(x+6, y, percent*10, PREC1)
    drawText(getLastPos(), y, '%', 0)
    drawText(x+6, y+54, linq .. 'dB', 0)

end


local function distWidget(x, y)

    local dist = getValue('Dist')

    drawPixmap(x+1, y+2, '/IMAGES/TELEM/dist.bmp')
    drawNumber(x+21, y+5, dist, MIDSIZE + LEFT)
    drawText(getLastPos(), y+8, 'm', 0)

end


local function altitudeWidget(x, y)

    local altitude = getValue(Altd)

    drawPixmap(x+1, y+2, '/IMAGES/TELEM/hgt.bmp')
    drawNumber(x+21, y+5, altitude, MIDSIZE + LEFT)
    drawText(getLastPos(), y+8, 'm', 0)

end


local function speedWidget(x, y)

    local speed = getValue('GSpd') * 3.6

    drawPixmap(x+1, y+2, '/IMAGES/TELEM/speed.bmp')
    drawNumber(x+21, y+5, speed, MIDSIZE + LEFT)
    drawText(getLastPos(), y+8, 'kmh', 0)

end


local function headingWidget(x, y)

    local heading = getValue('Hdg')

    drawPixmap(x+1, y+2, '/IMAGES/TELEM/compass.bmp')
    drawNumber(x+21, y+5, heading, MIDSIZE + LEFT)
    drawText(getLastPos(), y+8, 'dg', 0)

end


local function modeWidget(x, y)

    local m = math.floor(getValue('RPM') % 100)

    if linq <= 20 and m == 0 then m = -1 end -- No Telemetry

    drawPixmap(x+1, y+2, '/IMAGES/TELEM/fm.bmp')
    drawText(x+18, y+4, flightMode[m].name, MIDSIZE + flightMode[m].style)

    if prevMode ~= m and flightMode[m].sound then
        prevMode = m
        playFile(flightMode[m].sound .. '.wav')
    end

end


local function timerWidget(x, y)

    local style = MIDSIZE
    local timer = model.getTimer(0)
    if timer then
	timer = timer.value
    else
	timer = 0
    end
    if timer < 0 then
        style = style + INVERS
    end
    drawPixmap(x+1, y+3, '/IMAGES/TELEM/timer_1.bmp')
    drawTimer(x+21, y+5, timer, style)

end


local function gpsWidget(x,y)

    local sats = getValue('Sats')
    local fix  = getValue('Fix')

    local fixImg = '/IMAGES/TELEM/sat0.bmp'
    if     fix == 2 then fixImg = '/IMAGES/TELEM/sat1.bmp'
    elseif fix == 3 then fixImg = '/IMAGES/TELEM/sat2.bmp'
    elseif fix == 4 then fixImg = '/IMAGES/TELEM/sat3.bmp'
    end

    local satImg = '/IMAGES/TELEM/gps_0.bmp'
    if     sats > 5 then satImg = '/IMAGES/TELEM/gps_6.bmp'
    elseif sats > 4 then satImg = '/IMAGES/TELEM/gps_5.bmp'
    elseif sats > 3 then satImg = '/IMAGES/TELEM/gps_4.bmp'
    elseif sats > 2 then satImg = '/IMAGES/TELEM/gps_3.bmp'
    elseif sats > 1 then satImg = '/IMAGES/TELEM/gps_2.bmp'
    elseif sats > 0 then satImg = '/IMAGES/TELEM/gps_1.bmp'
    end

    drawPixmap(x+1, y+1, fixImg)
    drawPixmap(x+13, y+3, satImg)
    drawNumber(x+19, y+1, sats, SMLSIZE)

end


-- main logic  -----------------------------------------------------------------

local function run(event)

    lcd.clear()

    local x = -1
    local y = -1
    local w

    for col=1, #layout do
        if #layout[col] == 1 then
            w = widgetWidthSingle
        else
            w = widgetWidthMulti
        end

        for row=1, #layout[col] do
            drawLine(x, y, x+w, y, SOLID, GREY_DEFAULT)
            widget[layout[col][row]](x+1, y+1) --call widget
            y = y + math.floor(displayHeight / #layout[col])
        end

        y = -1
        x = x + w
    end

    dispTime = dispTime + (getTime() - prevTime)
    if dispTime >= 200 then -- 2s
	if displayFrame == 0 then 
	    displayFrame = 1 
	else 
	    displayFrame = 0
	end
	dispTime = 0
    end
    prevTime = getTime()

end


local function init()

    widget['alt'] = altitudeWidget
    widget['battery'] = batteryWidget
    widget['dist'] = distWidget
    widget['mode'] = modeWidget
    widget['gps'] = gpsWidget
    widget['heading'] = headingWidget
    widget['rssi'] = rssiWidget
    widget['speed'] = speedWidget
    widget['timer'] = timerWidget

    local colsSingle = 0
    local colsMulti  = 0
    for i=1, #layout do
        if #layout[i] == 1 then
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
