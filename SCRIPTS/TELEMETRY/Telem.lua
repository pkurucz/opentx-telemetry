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
local maxAmps	= 60	-- maximum current alert threshold
local minVolt	= 3.30	-- minimum voltage alert threshold per cell
local layout	= {	-- screen widgets
                    { 'battery' },
                    { 'gps', 'altitude', 'curr' },
                    { 'mode', 'speed', 'timer' },
                    { 'rssi' },
                  }
local LQG	= false	-- set to `true` for LQG builds, otherwise `false`


-- module globals  -------------------------------------------------------------

local options = {
                  { 'Altitude', SOURCE, 1 },
                  { 'Cells', VALUE, 4 },
                }

local battMin, battMax, imperial, language, voice = getGeneralSettings()
local version, radio, maj, min, rev = getVersion() 

local UNIT_VOLTS = 1
local UNIT_AMPS  = 2

local rssi = 0
local widgetWidthSingle = 35
local widgetWidthMulti = 0
local widget = {}

local flightMode = {}
flightMode[-2] = { name = 'Invalid',				style = BLINK }
flightMode[-1] = { name = 'No Telem',				style = BLINK }
flightMode[ 0] = { name = 'Manual',	sound = 'fm-mnl',	style = 0 }
flightMode[ 1] = { name = 'Acro',	sound = 'fm-acr',	style = 0 }
flightMode[ 2] = { name = 'Leveling',	sound = 'fm-lvl',	style = 0 }
flightMode[ 3] = { name = 'Horizon',	sound = 'fm-hrzn',	style = 0 }
flightMode[ 4] = { name = 'Axis Lock',	sound = 'fm-axlk',	style = 0 }
flightMode[ 5] = { name = 'VrtualBar',	sound = 'fm-vbar',	style = 0 }
flightMode[ 6] = { name = 'Stablzd 1',	sound = 'fm-stb1',	style = 0 }
flightMode[ 7] = { name = 'Stablzd 2',	sound = 'fm-stb2',	style = 0 }
flightMode[ 8] = { name = 'Stablzd 3',	sound = 'fm-stb3',	style = 0 }
flightMode[ 9] = { name = 'Auto Tune',	sound = 'fm-tune',	style = BLINK }
flightMode[10] = { name = 'Alt. Hold',	sound = 'fm-ahld',	style = 0 }
flightMode[11] = { name = 'Pos. Hold',	sound = 'fm-phld',	style = 0 }
flightMode[12] = { name = 'RtnToHome',	sound = 'fm-rth',	style = 0 }
flightMode[13] = { name = 'Path Plnr',	sound = 'fm-plan',	style = 0 }
flightMode[14] = { name = 'TabletCtl',	sound = 'fm-tblt',	style = 0 }
flightMode[15] = { name = 'Acro Plus',	sound = 'fm-acrp',	style = 0 }
flightMode[16] = { name = 'Acro Dyne',	sound = 'fm-acrd',	style = 0 }
flightMode[17] = { name = 'LQG Acro',	sound = 'fm-acr',	style = 0 }
flightMode[18] = { name = 'LQG Level',	sound = 'fm-lvl',	style = 0 }
flightMode[19] = { name = 'Fail Safe',	sound = 'fm-fail',	style = BLINK }

local bars = {}
for i=1, 10 do bars[i] = {} end
bars[10][3] = {  4, 10, 25 }
bars[10][2] = {  4, 11, 25 }
bars[10][1] = {  5, 12, 23 }
bars[ 9][3] = {  5, 14, 23 }
bars[ 9][2] = {  5, 15, 23 }
bars[ 9][1] = {  6, 16, 21 }
bars[ 8][3] = {  6, 18, 21 }
bars[ 8][2] = {  6, 19, 21 }
bars[ 8][1] = {  7, 20, 19 }
bars[ 7][3] = {  7, 22, 19 }
bars[ 7][2] = {  7, 23, 19 }
bars[ 7][1] = {  8, 24, 17 }
bars[ 6][3] = {  8, 26, 17 }
bars[ 6][2] = {  8, 27, 17 }
bars[ 6][1] = {  9, 28, 15 }
bars[ 5][3] = {  9, 30, 15 }
bars[ 5][2] = {  9, 31, 15 }
bars[ 5][1] = { 10, 32, 13 }
bars[ 4][3] = { 10, 34, 13 }
bars[ 4][2] = { 10, 35, 13 }
bars[ 4][1] = { 11, 36, 11 }
bars[ 3][3] = { 11, 38, 11 }
bars[ 3][2] = { 11, 39, 11 }
bars[ 3][1] = { 12, 40,  9 }
bars[ 2][3] = { 12, 42,  9 }
bars[ 2][2] = { 12, 43,  9 }
bars[ 2][1] = { 13, 44,  7 }
bars[ 1][3] = { 13, 46,  7 }
bars[ 1][2] = { 13, 47,  7 }
bars[ 1][1] = { 14, 48,  5 }

-- functions  -----------------------------------------------------------------

local getLastPos = lcd.getLastRightPos


local function round(n, p)
    p = 10^(p or 0)
    if n >= 0 then
        return math.floor(n * p + 0.5) / p
    else
        return math.ceil(n * p - 0.5) / p
    end
end


local Timer = {}
function Timer:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    self.ticks = 0
    self.time = getTime()
    return o
end


local post = Timer:new({ rssi=0, perc=0, altd=0, gspd=0, lat=0, lon=0, mode=0, batt=0, cell=0, curr=0 })
function post:refresh(ticks)
    self.ticks = self.ticks + (getTime() - self.time)
    if self.ticks >= ticks then
        self.ticks = 0
        if self.rssi == 0 and rssi > 0 then -- reset
            self.perc = 0
            self.altd = 0
            self.gspd = 0
            self.lat  = 0
            self.lon  = 0
            self.mode = 0
            self.batt = 35
            self.cell = 5
            self.curr = 0
            model.resetTimer(0)
        end
        self.rssi = rssi
    end
    self.time = getTime()
    return self
end


local draw = Timer:new()
function draw:refresh(ticks)
    self.ticks = self.ticks + (getTime() - self.time)
    if self.ticks >= ticks then
        self.ticks = 0
        if self.frame == 1 then 
            self.frame = 2 
        else 
            self.frame = 1
        end
    end
    self.time = getTime()
    return self
end


local curr = Timer:new({ mean=0 })
function curr:refresh(ticks)
    self.amps = getValue('Curr')
    self.mean = self.amps * 0.01 + self.mean * 0.99
    if self.mean > maxAmps then 
        self.ticks = self.ticks + (getTime() - self.time)
        if self.ticks >= ticks then
            self.ticks = 0
            playFile('currdrw.wav')
            playNumber(self.amps, UNIT_AMPS)
        end
        self.time = getTime()
    end
    return self
end


local batt = Timer:new({ cells=battCells, cellv=0, volts=0, fuel=0, perc=111 })
function batt:read()
    self.cellv = getValue('Cels')
    if type(self.cellv) == 'table' then -- FrSky FLVSS
        self.cells = 0
        for i, v in ipairs(self.cellv) do
            self.volts = self.volts + v
            self.cells = self.cells + 1
        end
    elseif self.cellv == 0 then
        self.volts = getValue('VFAS')
    else -- dRonin et al
        self.volts = self.cellv
    end

    if self.cells ~= 5 or self.cells ~= 7 then -- no autodetect for 5S & 7S
        if math.ceil(self.volts / 4.37) > self.cells and self.volts < 4.37 * 8 then 
            self.cells = math.ceil(self.volts / 4.37)
            if self.cells == 7 then self.cells = 8 end -- empty 8S looks like 7S
            if self.cells == 5 then self.cells = 6 end -- empty 6S looks like 5S
        end
    end

    if self.cells > 0 then 
        self.cellv = self.volts / self.cells 
    end

    local v = 0
    if self.volts > 4.22 * self.cells then -- High Volt
        v = self.cellv - 0.15
    else
        v = self.cellv
    end

    if post.rssi == 0 then -- No Telemetry
        self.fuel = 0
        self.perc = 111
        self.cellv = post.cell
        self.volts = post.batt
    elseif v > 0 and self.cellv < post.cell then
        post.cell = self.cellv
        post.batt = self.volts
    end

    if     v >  4.2		then v = 100
    elseif v <  3.2		then v = 0
    elseif v >= 4		then v = 80 * v - 236
    elseif v <= 3.67		then v = 29.787234 * v - 95.319149 
    elseif v >  3.67 and v < 4	then v = 212.53 * v - 765.29
    end

    if self.fuel == 0 then 
        self.fuel = round(v) --init percent
    else 
        self.fuel = round(self.fuel * 0.98 + 0.02 * v)
    end
    return self
end


function batt:refresh(ticks)
    self:read()
    if post.rssi > 0 and self.fuel < self.perc - 10 then 
        self.ticks = self.ticks + (getTime() - self.time)
        if self.ticks >= ticks then
            self.ticks = 0
            self.perc = round(self.fuel * 0.1) * 10
            if self.volts > 0.5 then
                if self.perc <= 10 then 
                    playFile('batcrit.wav') 
                end
                if self.cellv < minVolt then
                    playFile('battcns.wav')
                end
                playNumber(round(self.volts*10), UNIT_VOLTS, PREC1)
            end
        end
        self.time = getTime()
    end
    return self
end


-- widget functions  -----------------------------------------------------------

local function drawBattery(x, y)
    batt:read()

    lcd.drawText(x+10, y, batt.fuel .. '%', SMLSIZE)
    lcd.drawFilledRectangle(x+12, y+9, 7, 2, 0)
    lcd.drawRectangle(x+9, y+11, 13, 40)

    local myPxHeight = math.floor(batt.fuel * 0.37)
    local myPxY = 13 + 37 - myPxHeight
    if batt.fuel > 0 then
        lcd.drawFilledRectangle(x+10, myPxY, 11, myPxHeight, 0)
    end

    for i=36, 1, -2 do
        lcd.drawLine(x+11, y+12+i, x+19, y+12+i, SOLID, GREY_DEFAULT)
    end

    local style = LEFT + PREC2
    if batt.cellv < minVolt then
        style = style + BLINK
    end

    if draw.frame == 1 then
        lcd.drawText(x, y+54, batt.cells .. 'S', 0)
        lcd.drawNumber(getLastPos()+1, y+54, batt.cellv*100, style)
    elseif draw.frame == 2 then
        lcd.drawNumber(x+5, y+54, batt.volts*100, style)
    end
    lcd.drawText(getLastPos(), y+54, 'V', 0)
end


local function drawRSSI(x, y)
    rssi = getRSSI()
    if rssi > 38 then
        post.perc = round(post.perc * 0.5 + 0.5 * (((math.log(rssi - 28, 10) - 1) / (math.log(72, 10) - 1)) * 100))
	if post.perc > 100 then post.perc = 100 end
    else
	post.perc = 0
    end
    local flags = FORCE
    for i=1, #bars do
        if i > math.ceil(post.perc * 0.1) then flags = GREY_DEFAULT end
	for j=1, #bars[i] do
	    local x = x + bars[i][j][1]
	    local y = y + bars[i][j][2]
	    local l = x + bars[i][j][3]
	    if j == 1 and i ~= 1 and flags == FORCE then
		lcd.drawLine(x-1, y, l+1, y, SOLID, GREY_DEFAULT)
	    end
	    lcd.drawLine(x, y, l, y, SOLID, flags)
	end
    end
    lcd.drawText(x+10, y, post.perc .. '%', 0)
    lcd.drawText(x+8, y+54, rssi .. 'dB', 0)
end


local function drawGPS(x, y)
    local fmt = '% .6f'
    local gps = getValue('GPS')
    if rssi > 0 and type(gps) == 'table' then
        post.lat = gps.lat
        post.lon = gps.lon
    end
    lcd.drawFilledRectangle(x+1, y+1, 18, 17, SOLID)
    lcd.drawText(x+3, y+3,  'Lat', SMLSIZE + INVERS)
    lcd.drawText(x+3, y+10, 'Lon', SMLSIZE + INVERS)
    lcd.drawText(x+69, y+3,  string.format(fmt, post.lat), SMLSIZE + RIGHT)
    lcd.drawText(x+69, y+11, string.format(fmt, post.lon), SMLSIZE + RIGHT)
end


local function drawMode(x, y)
    local m = math.floor(getValue('RPM') % 100)
    if post.rssi == 0 and m == 0 then m = -1 end -- No Telemetry
    if not flightMode[m] then m = -2 end -- Invalid Flight Mode
    if not LQG and m == 17 then m = 19 end -- LQG FailSafe kludge
    lcd.drawText(x+2, y+4, flightMode[m].name, MIDSIZE + flightMode[m].style)
    if post.rssi > 0 and m ~= post.mode and flightMode[m].sound then
        playFile(flightMode[m].sound .. '.wav')
        post.mode = m
    end
end


local function drawCurr(x, y)
    local curr = getValue('Curr')
    if rssi == 0 then -- No Telemetry
        curr = post.curr
    elseif curr > post.curr then
        post.curr = curr
    end
    lcd.drawFilledRectangle(x+1, y+2, 26, 16, SOLID)
    lcd.drawText(x+2, y+4, 'Cur', MIDSIZE + INVERS)
    lcd.drawNumber(x+30, y+4, curr*10, MIDSIZE + LEFT + PREC1)
    lcd.drawText(getLastPos(), y+7, 'A', 0)
end


local function drawDist(x, y)
    local dist = getValue('Dist')
    local unit = 'm'
    if imperial ~= 0 then unit = 'ft' end
    lcd.drawFilledRectangle(x+1, y+2, 26, 16, SOLID)
    lcd.drawText(x+2, y+4, 'Dst', MIDSIZE + INVERS)
    lcd.drawNumber(x+30, y+4, dist, MIDSIZE + LEFT)
    lcd.drawText(getLastPos(), y+7, unit, 0)
end


local function drawAltitude(x, y)
    local altitude = getValue(Altd)
    local unit = 'm'
    if imperial ~= 0 then unit = 'ft' end
    if rssi == 0 then -- No Telemetry
        altitude = post.altd
    elseif altitude > post.altd then
        post.altd = altitude
    end
    lcd.drawFilledRectangle(x+1, y+2, 26, 16, SOLID)
    lcd.drawText(x+2, y+4, 'Alt', MIDSIZE + INVERS)
    lcd.drawNumber(x+30, y+4, altitude, MIDSIZE + LEFT)
    lcd.drawText(getLastPos(), y+7, unit, 0)
end


local function drawSpeed(x, y)
    local speed = getValue('GSpd')
    local unit = 'kts'
    if imperial == 0 then
        speed = round(speed*1.851*2)
        unit = 'kmh'
    else
        speed = round(speed*1.149)
        unit = 'mph'
    end
    if rssi == 0 then -- No Telemetry
        speed = post.gspd
    elseif speed > post.gspd then
        post.gspd = speed
    end
    lcd.drawFilledRectangle(x+1, y+2, 26, 16, SOLID)
    lcd.drawText(x+2, y+4, 'Spd', MIDSIZE + INVERS)
    lcd.drawNumber(x+30, y+4, speed, MIDSIZE + LEFT)
    lcd.drawText(getLastPos(), y+7, unit, 0)
end


local function drawHeading(x, y)
    local heading = getValue('Hdg')
    lcd.drawFilledRectangle(x+1, y+2, 26, 16, SOLID)
    lcd.drawText(x+2, y+4, 'Hdg', MIDSIZE + INVERS)
    lcd.drawNumber(x+30, y+4, heading, MIDSIZE + LEFT)
    lcd.drawText(getLastPos(), y+7, 'dg', 0)
end


local function drawTimer(x, y)
    local style = MIDSIZE
    local timer = model.getTimer(0)
    if timer then
        timer = timer.value
    else
        timer = 0
    end
    local xx = 30
    if timer < 0 then
        style = style + INVERS
        xx = 36
    end
    lcd.drawFilledRectangle(x+1, y+2, 26, 16, SOLID)
    lcd.drawText(x+2, y+4, 'Tmr', MIDSIZE + INVERS)
    lcd.drawTimer(x+xx, y+4, timer, style)
end


-- main logic  -----------------------------------------------------------------

local function create(zone, options)

    widget.altitude = drawAltitude
    widget.battery  = drawBattery
    widget.curr     = drawCurr
    widget.dist     = drawDist
    widget.mode     = drawMode
    widget.gps      = drawGPS
    widget.heading  = drawHeading
    widget.rssi     = drawRSSI
    widget.speed    = drawSpeed
    widget.timer    = drawTimer

    local colsSingle = 0
    local colsMulti  = 0
    for i=1, #layout do
        if #layout[i] == 1 then
            colsSingle = colsSingle + 1
        else
            colsMulti = colsMulti + 1
        end
    end

    widgetWidthMulti = (LCD_W - (colsSingle * widgetWidthSingle)) / colsMulti

    return { zone=zone, options=options }
end


local function update(zone, options)
    zone.options = options
end


local function background(zone)
    curr:refresh(250) -- 2.5 seconds
    batt:refresh(800) -- 8 seconds
    post:refresh(100) -- 1 second
end


local function refresh(zone)

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
            lcd.drawLine(x, y, x+w, y, SOLID, GREY_DEFAULT)
            widget[layout[col][row]](x+1, y+1) --call widget
            y = y + math.floor(LCD_H / #layout[col])
        end

        y = -1
        x = x + w
    end

    draw:refresh(200) -- 2 seconds
    background(zone)

end


-- module definition  ----------------------------------------------------------

return { name='Telem', options=options, update=update, create=create, init=create, refresh=refresh, run=refresh, background=background }
