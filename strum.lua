-- 
-- strum
--
-- "Full moon shines so bright
--     Stars in its vicinity
--       All but disappear"
--
--
-- grid Controls
-- --
-- grid pads to change pitch
-- Double tap to add a rest
--
-- Front Controls
-- --
-- ENC 1: adjusts direction
-- ENC 2: adjusts tempo
-- ENC 3: sets scale
-- KEY 2: randomizes pattern
-- KEY 3: pauses/restarts
--
-- MIDI OUT: to external synths
--
-- Param Settings
-- --
-- Light Show or single light
-- Set grid and MIDI device
-- Set grid rotation
-- Set MIDI channel
-- Various clock settings
-- Synth params can be changed
-- -- beware the high ends!!!
--
--
-- Based on norns study #4
--
-- @carvingcode (Randy Brown)
-- v0.7d_0308 (for v2.x)



engine.name = 'KarplusRings'

local cs = require 'controlspec'
local music = require 'musicutil'
local beatclock = require 'beatclock'

local name = ":: strum :: "

local steps = {}

local playmode = {"Onward","Aft","Sway","Joy"}
local out_options = {"Audio", "MIDI", "Audio + MIDI"}

local grid_device = grid.connect()

local midi_out_device = midi.connect(2)
local midi_out_channel

local playchoice = 1
local position = 1
local note_playing = nil
local prev_note = 0
local next_step = 0
local transpose = 0
local direction = 1
local k3_state = 0

local lightshow = 1

--local mode = math.random(#music.SCALES)
local mode = 17
local scale = music.generate_scale_of_length(60,music.SCALES[mode].name,8)

local clk = beatclock.new()
local clk_midi = midi.connect()
clk_midi.event = clk.process_midi


local function all_notes_kill()
  
  -- Audio engine out
  --engine.noteKillAll(). ??
  
  -- MIDI out
  if (params:get("output") == 2 or params:get("output") == 3) then
      midi_out_device:note_off(a, 96, midi_out_channel)
  end
  note_playing = nil
end


local function reset_pattern()
	playchoice = 1
	position = 0
	note_playing = nil
	clk:reset()
end

--
-- each step
--
function handle_step()

    --print(playmode[playchoice])
    if playmode[playchoice] == "Onward" then
        position = (position % 16) + 1
    elseif playmode[playchoice] == "Aft" then
        position = position - 1
        if position == 0 then
            position = 16
        end
    elseif playmode[playchoice] == "Sway" then
        if direction == 1 then
            position = (position % 16) + 1
            if position == 16 then
                direction = 0
            end
        else
            position = position - 1
            if position == 1 then
                direction = 1
            end
        end
    else
        position = math.random(1,16)
    end

    if steps[position] ~= 0 then
        vel = math.random(1,100) / 100 -- random velocity values
        --print(vel)
        
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

--
-- setup
--
function init()

    for i=1,16 do
        table.insert(steps,math.random(0,8))
    end
    
    grid_redraw()
    redraw()

    clk.on_step = handle_step
    clk.on_stop = reset_pattern

	clk.on_select_internal = function() clk:start() end
	clk.on_select_external = reset_pattern

	params:add_option("light_show", "Light Show", { "yes", "no" }, lightshow or 2 and 1)
	params:set_action("light_show", function(x) if x == 1 then lightshow = 1 else lightshow = 2 end end)
	
	params:add_separator("Clock")
	
	params:add_option("clock", "Clock", {"internal", "external"}, clk.external or 2 and 1)
	params:set_action("clock", function(x) clk:clock_source_change(x) end)
	params:add_number("bpm", "BPM", 1, 480, clk.bpm)
	params:set_action("bpm", function(x) clk:bpm_change(x) end)
	params:add_option("clock_out", "Clock Out", { "no", "yes" }, clk.send or 2 and 1)
	params:set_action("clock_out", function(x) if x == 1 then clk.send = false else clk.send = true end end)
	params:set("bpm", 72)
   
    params:add_separator()
	
	params:add{type = "number", id = "grid_device", name = "Grid Device", min = 1, max = 4, default = 1, 
		action = function(value)
		grid_device:all(0)
		grid_device:refresh()
		grid_device = grid.connect(value)
    end}
    
    params:add{type = "number", id = "grid_rotation", name = "Grid Rotation", min = 0, max = 3, default = 0, 
		action = function(value)
		grid_device:all(0)
		grid_device:rotation(value)
		grid_device:refresh()
		--grid_device = grid.rotation(value)
    end}
  
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

    clk:start()

end


--
-- grid functions
--

grid_device.key = function(x,y,z)
    --print(x,y,z)
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

function grid_redraw()
    grid_device:all(0)
    for i=1,16 do
	    if lightshow == 1 then
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

--
-- norns keys
--
function key(n,z)
    if n == 2 and z == 1 then
	    --print ("key 2 pressed")
	    steps = {}
        for i=1,16 do
        	table.insert(steps,math.random(0,8))
    	end
    end
    if n == 3 and z == 1 then
        --prompt = "key 3 pressed"
        if k3_state == 0 then
            clk:stop()
            grid_device:all(0)
            grid_device:refresh()
            k3_state = 1
            
            -- MIDI out
			if (params:get("output") == 2 or params:get("output") == 3) then
            	all_notes_kill()
            end
            reset_pattern()
        else
            clk:start()
            k3_state = 0
        end
    end
    --if z == 0 then
    --prompt = "key released"
    --end
    redraw()
end

--
-- norns encoders
--
function enc(n,d)
    if n == 1 then          -- sequence direction
        playchoice = util.clamp(playchoice + d, 1, #playmode)
        --print (playchoice)
    elseif n == 2 then      -- tempo
        params:delta("bpm",d)
    elseif n == 3 then      -- scale
        mode = util.clamp(mode + d, 1, #music.SCALES)
        scale = music.generate_scale_of_length(60,music.SCALES[mode].name,8)
    end
    redraw()
end

--
-- norns screen display
--
function redraw()
    screen.clear()
    screen.move(44,10)
    screen.level(5)
    screen.text(name)
    screen.move(0,20)
    screen.text("---------------------------------")
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
    screen.move(0,50)
    screen.level(5)
    screen.text("Scale: ")
    screen.move(30,50)
    screen.level(15)
    screen.text(music.SCALES[mode].name)
    screen.update()
end


function cleanup ()
  clk:stop()
end