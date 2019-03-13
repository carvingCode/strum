-- 
-- Strum: plucky patterns
--
-- "Full moon shines so bright
--      Stars in its vicinity
--          All but disappear"
--
--
-- grid Controls
-- 
-- Tap grid pads to set/change pitch. 
-- Or randomize them with K2.
-- Double tap to add a rest.
-- 
-- norns Controls
-- 
-- Dividied into pages
-- 
-- ENC 1: chooses page
-- 
-- Page 1
-- 
-- ENC 2: adjusts direction
-- ENC 3: adjusts tempo
-- 
-- Page 2
-- 
-- ENC 2: sets scale
-- 
-- ENC 3: sets pattern length
-- 
-- KEY 2: randomizes pattern
-- 
-- KEY 3: pauses/restarts
-- 
-- MIDI
-- 
-- MIDI IN: clock sync
-- MIDI OUT: to external synths
-- 
-- Param Settings
-- 
-- Grid display: scatter or bar
-- Set grid and MIDI device
-- Set grid rotation
-- Set MIDI channel
-- Various clock settings
-- Synth params can be changed (beware the high ends!!!) -- Delay can be set using "cut1rate" (new)
-- 
-- 
-- Based on norns study #4
-- 
-- @carvingcode (Randy Brown)
-- v0.7d_0313 (for v2.x)
--


engine.name = 'KarplusRings'

local UI = require "ui"
local cs = require 'controlspec'
local music = require 'musicutil'
local beatclock = require 'beatclock'
local h = require 'halfsecond'

local playmode = {"Onward","Aft","Joy"}
local out_options = {"Audio", "MIDI", "Audio + MIDI"}

--local grid_display_options = {["0"] = 0, ["90"] = 1, ["180"] = 2, ["270"] = 3}

-- vars for UI
local SCREEN_FRAMERATE = 15
local screen_refresh_metro
local screen_dirty = true
local pages

local name = ":: Strum :: "

-- pattern vars
local steps = {}
local playchoice = 1
local pattern_len = 16
local position = 1

local note_playing = nil
local prev_note = 0
local next_step = 0
local transpose = 0
local direction = 1
local k3_state = 0

-- device vars
local grid_device = grid.connect()
local midi_in_device = midi.connect()
local midi_out_device = midi.connect()
local midi_out_channel

-- scale vars
local mode = 5 -- set to dorian
local scale = music.generate_scale_of_length(60,music.SCALES[mode].name,8)

-- clock vars
local clk = beatclock.new()
local clk_midi = midi.connect()
clk_midi.event = clk.process_midi

----------------
-- stop notes --   TODO build this out
----------------
local function all_notes_kill()
  
  -- Audio engine out
  --engine.noteKillAll(). ??
  
  -- MIDI out
  if (params:get("output") == 2 or params:get("output") == 3) then
      midi_out_device:note_off(a, 96, midi_out_channel)
  end
  note_playing = nil
end

-------------------
-- reset pattern --	TODO finish
-------------------
local function reset_pattern()
    --playchoice = 1
    --position = 1
    --note_playing = nil
    clk:reset()
end

----------------------
-- handle each step --
----------------------
function handle_step()

    if playmode[playchoice] == "Onward" then
        position = (position % pattern_len) + 1
        
    elseif playmode[playchoice] == "Aft" then
        position = position - 1
        if position == 0 then
            position = pattern_len
        end
        
        -- 	TODO fix math
        
        --[[
    elseif playmode[playchoice] == "Sway" then
        if direction == 1 then
            position = (position % pattern_len) + 1
            if position == pattern_len then
                direction = 0
            end
        else
             if pattern_len > 1 then
                position = position - 1
            end
            if position == 1 then
                direction = 1
            end
        end
        --]]
    else -- random step position
        position = math.random(1,pattern_len)
    end

    if steps[position] ~= 0 then
        vel = math.random(1,100) / 100 -- random velocity values
        
          -- Audio engine out
        if params:get("output") == 1 or params:get("output") == 3 then
                engine.amp(vel)
                engine.hz(music.note_num_to_freq(scale[steps[position]] + transpose))
        end
        
            -- MIDI out
        if (params:get("output") == 2 or params:get("output") == 3) then
            if note_playing ~= nil then
                midi_out_device:note_off(note_playing,nil)
            end
            note_playing = music.freq_to_note_num(music.note_num_to_freq(scale[steps[position]] + transpose),1)
            midi_out_device:note_on(note_playing,vel*100)
        end
        
    end
    grid_redraw()
end

-----------
-- setup --
-----------
function init()

	screen.aa(1)
  
	-- Init UI
  	pages = UI.Pages.new(1, 3)
  
  	-- Start drawing to screen
  	screen_refresh_metro = metro.init()
  	screen_refresh_metro.event = function()
  		if screen_dirty then
      		screen_dirty = false
	  		redraw()
    	end
    end
	screen_refresh_metro:start(1 / SCREEN_FRAMERATE)
  
	-- initialize pattern with random notes
    for i=1,16 do
        table.insert(steps,math.random(0,8))
    end

	-- set clock functions
    clk.on_step = handle_step
    clk.on_stop = reset_pattern
    clk.on_select_internal = function() clk:start() end
    clk.on_select_external = reset_pattern

	-- set up parameter menu

    params:add_number("bpm", "BPM", 1, 480, clk.bpm)
    params:set_action("bpm", function(x) clk:bpm_change(x) end)
    params:set("bpm", 72)
    
    params:add_separator()
    
    params:add{type = "number", id = "grid_device", name = "Grid Device", min = 1, max = 4, default = 1, 
        action = function(value)
        grid_device:all(0)
        grid_device:refresh()
        grid_device = grid.connect(value)
    end}
    
    params:add_option("grid_display", "Grid Display", { "Bar", "Scatter" }, grid_display or 1 and 2)
    params:set_action("grid_display", function(x) if x == 1 then grid_display = 1 else grid_display = 2 end end)
  
 --[[ 
    params:add_option("grid_rotation", "Grid Rotation", grid_display_options, 0)
    params:set_action("grid_rotation", function(x) 
        grid_device:all(0)
        grid_device:rotation(x)
        grid_device:refresh()
    end)       
--]]

	-- working, not ideal
    params:add{type = "number", id = "grid_rotation", name = "Grid Rotation", min = 0, max = 3, default = 0, 
		action = function(value)
		grid_device:all(0)
		grid_device:rotation(value)
		grid_device:refresh()
    end}

    params:add_separator()
    
    params:add{type = "option", id = "output", name = "Output", options = out_options, 
        action = all_notes_kill}
        
    params:add{type = "number", id = "midi_out_device", name = "MIDI Out Device", min = 1, max = 4, default = 1,
        action = function(value)
        midi_out_device = midi.connect(value)
    end}
  
    params:add{type = "number", id = "midi_out_channel", name = "MIDI Out Channel", min = 1, max = 16, default = 1,
        action = function(value)
        all_notes_kill()
        midi_out_channel = value
    end}
    
	params:add{type = "number", id = "clock_midi_in_device", name = "Clock MIDI In Device", min = 1, max = 4, default = 1,
    	action = function(value)
		midi_in_device = midi.connect(value)
    end}
  
	params:add{type = "option", id = "clock_out", name = "Clock Out", options = {"Off", "On"}, default = clk.send or 2 and 1,
    	action = function(value)
		if value == 1 then clk.send = false
		else clk.send = true end
    end}
  
    params:add_separator()

    cs.AMP = cs.new(0,1,'lin',0,0.5,'')
    params:add_control("amp", "Amp", cs.AMP)
    params:set_action("amp",
        function(x) engine.amp(x) end)

    cs.DECAY = cs.new(0.1,15,'lin',0,3.6,'s')
    params:add_control("damping", "Damping", cs.DECAY)
    params:set_action("damping",
        function(x) engine.decay(x) end)

    cs.COEF = cs.new(0.2,0.9,'lin',0,0.2,'')
    params:add_control("brightness", "Brightness", cs.COEF)
    params:set_action("brightness",
        function(x) engine.coef(x) end)

    cs.LPF_FREQ = cs.new(100,10000,'lin',0,4500,'')
    params:add_control("lpf_freq", "LPF Freq", cs.LPF_FREQ)
    params:set_action("lpf_freq",
        function(x) engine.lpf_freq(x) end)

    cs.LPF_GAIN = cs.new(0,3.2,'lin',0,0.5,'')
    params:add_control("lpf_gain", "LPF Gain", cs.LPF_GAIN)
    params:set_action("lpf_gain",
        function(x) engine.lpf_gain(x) end)

    cs.BPF_FREQ = cs.new(100,4000,'lin',0,0.5,'')
    params:add_control("bpf_freq", "BPF Freq", cs.BPF_FREQ)
    params:set_action("bpf_freq",
        function(x) engine.bpf_freq(x) end)

    cs.BPF_RES = cs.new(0,3,'lin',0,0.5,'')
    params:add_control("bpf_res", "BPF Res", cs.BPF_RES)
    params:set_action("bpf_res",
        function(x) engine.bpf_res(x) end)

    params:bang()

	-- set up MIDI in
    midi_in_device.event = function(data)
    	clk:process_midi(data)
		if not clk.playing then
			screen_dirty = true
    	end
	end
    
	clk:start()
        
    --h.init()
end


-------------------------
-- handle grid presses --
-------------------------
grid_device.key = function(x,y,z)

    if z == 1 then
        if steps[x] == y then
            steps[x] = 0
        else
            steps[x] = y
        end
        grid_redraw()
    end
    redraw()
end

---------------------
-- redraw the grid --
---------------------
function grid_redraw()
	
    grid_device:all(0)
    for i=1,pattern_len do
         if grid_display == 1 then
            if steps[i] ~= 0 then
                for j=0,7 do
                    grid_device:led(i,steps[i]+j,i==position and 12 or (2+j))
                end
            end
        else
            grid_device:led(i,steps[i],i==position and 12 or 4)
        end
    end
    grid_device:refresh()
end

-----------------------
-- handle norns keys --
-----------------------
function key(n,z)
	
    if n == 2 and z == 1 then
         steps = {}
        for i=1,16 do
            table.insert(steps,math.random(0,8))
        end
    end
    if n == 3 and z == 1 then
        if k3_state == 0 then
            clk:stop()
            k3_state = 1
            
            -- MIDI out
            if (params:get("output") == 2 or params:get("output") == 3) then
                all_notes_kill()
            end
            -- clear grid lights
            grid_device:all(0)
            grid_device:refresh()
        else
            reset_pattern()
            clk:start()
            k3_state = 0
        end
    end

    redraw()
end

---------------------------
-- handle norns encoders --
---------------------------
function enc(n,delta)
	
    -- handle UI paging
    if n == 1 then
    -- Page scroll
        pages:set_index_delta(util.clamp(delta, -1, 1), false)
    end
  
    if pages.index == 1 then
        
        if n == 2 then           -- sequence direction
            playchoice = util.clamp(playchoice + delta, 1, #playmode)
        elseif n == 3 then      -- tempo
            params:delta("bpm",delta)
        end
        
    elseif pages.index == 2 then

        if n == 2 then       -- scale
            mode = util.clamp(mode + delta, 1, #music.SCALES)
            scale = music.generate_scale_of_length(60,music.SCALES[mode].name,8)
        elseif n == 3 then
            pattern_len = util.clamp(pattern_len + delta, 2, 16)
        end
        
    end
    redraw()
    
    screen_dirty = true
end

-------------------------
-- handle norns screen --
-------------------------
function redraw()
	
    screen.clear()
    
    pages:redraw()
    
    screen.aa(1)
    screen.line_width(1)
    screen.move(44,10)
    screen.level(5)
    screen.text(name)
    screen.move(0,15)
    screen.line(127,15)
    screen.stroke()
    
    if pages.index == 1 then
	    
        screen.move(0,30)
        screen.level(5)
        screen.text("Path: ")
        screen.move(30,30)
        screen.level(15)
        screen.text(playmode[playchoice])
        screen.move(0,40)
        screen.level(5)
        screen.text("Tempo: ")
        screen.move(30,40)
        screen.level(15)
        screen.text(params:get("bpm").." bpm")
        
    elseif pages.index == 2 then
        screen.move(0,30)
        screen.level(5)
        screen.text("Scale: ")
        screen.move(30,30)
        screen.level(15)
        screen.text(music.SCALES[mode].name)
        screen.move(0,40)
        screen.level(5)
        screen.text("Len: ")
        screen.move(30,40)
        screen.level(15)
        screen.text(pattern_len)
        
    elseif pages.index == 3 then
         screen.move(0,30)
         screen.text(":: you are here ::")
    end
    
    screen.update()
end


function cleanup ()
  clk:stop()
end
