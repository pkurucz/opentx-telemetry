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
local displayWidth = 212
local displayHeight = 64
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

local image = {}
image.altitude = '/IMAGES/TELEM/hgt.bmp'
image.compass  = '/IMAGES/TELEM/compass.bmp'
image.dist     = '/IMAGES/TELEM/dist.bmp'
image.mode     = '/IMAGES/TELEM/fm.bmp'
image.speed    = '/IMAGES/TELEM/speed.bmp'
image.timer    = '/IMAGES/TELEM/timer_1.bmp'
image.rssi00   = '/IMAGES/TELEM/RSSIh00.bmp'
image.rssi01   = '/IMAGES/TELEM/RSSIh01.bmp'
image.rssi02   = '/IMAGES/TELEM/RSSIh02.bmp'
image.rssi03   = '/IMAGES/TELEM/RSSIh03.bmp'
image.rssi04   = '/IMAGES/TELEM/RSSIh04.bmp'
image.rssi05   = '/IMAGES/TELEM/RSSIh05.bmp'
image.rssi06   = '/IMAGES/TELEM/RSSIh06.bmp'
image.rssi07   = '/IMAGES/TELEM/RSSIh07.bmp'
image.rssi08   = '/IMAGES/TELEM/RSSIh08.bmp'
image.rssi09   = '/IMAGES/TELEM/RSSIh09.bmp'
image.rssi10   = '/IMAGES/TELEM/RSSIh10.bmp'
image.sat0     = '/IMAGES/TELEM/sat0.bmp'
image.sat1     = '/IMAGES/TELEM/sat1.bmp'
image.sat2     = '/IMAGES/TELEM/sat2.bmp'
image.sat3     = '/IMAGES/TELEM/sat3.bmp'
image.gps0     = '/IMAGES/TELEM/gps_0.bmp'
image.gps1     = '/IMAGES/TELEM/gps_1.bmp'
image.gps2     = '/IMAGES/TELEM/gps_2.bmp'
image.gps3     = '/IMAGES/TELEM/gps_3.bmp'
image.gps4     = '/IMAGES/TELEM/gps_4.bmp'
image.gps5     = '/IMAGES/TELEM/gps_5.bmp'
image.gps6     = '/IMAGES/TELEM/gps_6.bmp'


-- functions  -----------------------------------------------------------------

local getLastPos = lcd.getLastRightPos


local function drawBitmap(x, y, image)
    if radio == 'x10' or radio == 'x12s' then
        return lcd.drawBitmap(image, x, y)
    else
        return lcd.drawPixmap(x, y, image)
    end
end


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


local post = Timer:new({ rssi=0, altd=0, gspd=0, lat=0, lon=0, mode=0, batt=0, cell=0, curr=0 })
function post:refresh(ticks)
    self.ticks = self.ticks + (getTime() - self.time)
    if self.ticks >= ticks then
        self.ticks = 0
        if self.rssi == 0 and rssi > 0 then -- reset
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
    lcd.drawFilledRectangle(x+13, y+9, 5, 2, 0)
    lcd.drawRectangle(x+10, y+11, 11, 40)

    local myPxHeight = math.floor(batt.fuel * 0.37)
    local myPxY = 13 + 37 - myPxHeight
    if batt.fuel > 0 then
        lcd.drawFilledRectangle(x+11, myPxY, 9, myPxHeight, 0)
    end

    for i=36, 1, -2 do
        lcd.drawLine(x+12, y+12+i, x+18, y+12+i, SOLID, GREY_DEFAULT)
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
        
    local percent = 0
    if rssi > 38 then
        percent = (math.log(rssi - 28, 10) - 1) / (math.log(72, 10) - 1) * 100
    end

    local pixmap = image.rssi00
    if     percent > 90 then pixmap = image.rssi10
    elseif percent > 80 then pixmap = image.rssi09
    elseif percent > 70 then pixmap = image.rssi08
    elseif percent > 60 then pixmap = image.rssi07
    elseif percent > 50 then pixmap = image.rssi06
    elseif percent > 40 then pixmap = image.rssi05
    elseif percent > 30 then pixmap = image.rssi04
    elseif percent > 20 then pixmap = image.rssi03
    elseif percent > 10 then pixmap = image.rssi02
    elseif percent >  0 then pixmap = image.rssi01
    end

    drawBitmap(x+4, y+3, pixmap)
    lcd.drawNumber(x+6, y, percent * 10, PREC1)
    lcd.drawText(getLastPos(), y, '%', 0)
    lcd.drawText(x+6, y+54, rssi .. 'dB', 0)
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
    lcd.drawText(x+21, y+3,  string.format(fmt, post.lat), SMLSIZE)
    lcd.drawText(x+21, y+10, string.format(fmt, post.lon), SMLSIZE)
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
    lcd.drawNumber(x+30, y+4, curr, MIDSIZE + LEFT)
    lcd.drawText(getLastPos(), y+7, 'Amp', 0)
end


local function drawDist(x, y)
    local dist = getValue('Dist')
    lcd.drawFilledRectangle(x+1, y+2, 26, 16, SOLID)
    lcd.drawText(x+2, y+4, 'Dst', MIDSIZE + INVERS)
    lcd.drawNumber(x+30, y+4, dist, MIDSIZE + LEFT)
    lcd.drawText(getLastPos(), y+7, 'm', 0)
end


local function drawAltitude(x, y)
    local altitude = getValue(Altd)
    if rssi == 0 then -- No Telemetry
        altitude = post.altd
    elseif altitude > post.altd then
        post.altd = altitude
    end
    lcd.drawFilledRectangle(x+1, y+2, 26, 16, SOLID)
    lcd.drawText(x+2, y+4, 'Alt', MIDSIZE + INVERS)
    lcd.drawNumber(x+30, y+4, altitude, MIDSIZE + LEFT)
    lcd.drawText(getLastPos(), y+7, 'm', 0)
end


local function drawSpeed(x, y)
    local speed = getValue('GSpd') * 3.6
    if rssi == 0 then -- No Telemetry
        speed = post.gspd
    elseif speed > post.gspd then
        post.gspd = speed
    end
    lcd.drawFilledRectangle(x+1, y+2, 26, 16, SOLID)
    lcd.drawText(x+2, y+4, 'Spd', MIDSIZE + INVERS)
    lcd.drawNumber(x+30, y+4, speed, MIDSIZE + LEFT)
    lcd.drawText(getLastPos(), y+7, 'kmh', 0)
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

    widgetWidthMulti = displayWidth - (colsSingle * widgetWidthSingle)
    widgetWidthMulti = widgetWidthMulti / colsMulti

    if radio == 'x10' or radio == 'x12s' then
        for name, path in pairs(image) do
            image[name] = Bitmap.open(path)
        end
    end

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
            y = y + math.floor(displayHeight / #layout[col])
        end

        y = -1
        x = x + w
    end

    draw:refresh(200) -- 2 seconds
    background(zone)

end


-- module definition  ----------------------------------------------------------

return { name='Telem', options=options, update=update, create=create, init=create, refresh=refresh, run=refresh, background=background }
