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
-- - ENC 2: set scale
-- - ENC 3: set root note (tonic)
-- Page 2
-- - ENC 2: set play order
-- - ENC 3: set BPM (tempo)
-- - ALT (Key 1) & ENC 2:
-- -- set pattern length
-- Page 3:
-- Load/Save?delete
-- - ENC 3: change selection
-- - KEY 3: tap to select
-- - ENC 2: scroll list
-- All Pages
-- - ALT + KEY 2: randomizes pattern
-- - KEY 3: pauses/restarts
-- MIDI
-- - MIDI IN: clock sync
-- - MIDI OUT: to external synths
--
-- Param Settings
-- - Grid display: scatter or bar
-- - Set grid and MIDI device
-- - Set grid rotation
-- - Set MIDI channel
-- - Various clock settings
-- 
-- 
-- @carvingcode
-- v1.0_0329 (for v2)
-- 
--


engine.name = 'KarplusRings'

local UI = require "ui"
local cs = require 'controlspec'
local music = require 'musicutil'
local beatclock = require 'beatclock'
--local h = require 'halfsecond'

local playmode = {"Onward","Aft", "Sway", "Joy"}
local out_options = {"Audio", "MIDI", "Audio + MIDI"}
local grid_display_options = {"Normal", "180 degrees"}
local DATA_FILE_PATH = _path.data .. "ccode/strum/strum.data"

-- vars for UI
local SCREEN_FRAMERATE = 15
local screen_dirty = true
local GRID_FRAMERATE = 30
local grid_dirty = true
local pages
local alt = false

local name = ":: Strum :: "

-- pattern vars
local steps = {}
local playchoice = 1
local pattern_len = 16
local position = 1

local note_playing = nil
local prev_note = 0
local next_step = 0
local direction = 1
local k3_state = 0

-- device vars
local grid_device = grid.connect()
local midi_in_device = midi.connect()
local midi_out_device = midi.connect()
local midi_out_channel

-- scale vars
local root_num = 60
local tonic = music.note_num_to_name(root_num, 1)
local mode = 5 -- set to dorian
local scale = music.generate_scale_of_length(root_num,music.SCALES[mode].name,8)

-- clock vars
local beat_clock = beatclock.new()
local beat_clock_midi = midi.connect()
beat_clock_midi.event = beat_clock.process_midi

local save_data = {version = 1, patterns = {}}
local save_menu_items = {"Load", "Save", "Delete"}
local save_slot_list
local save_menu_list
local last_edited_slot = 0
local confirm_message
local confirm_function


local function copy_object(object)
  if type(object) ~= 'table' then return object end
  local result = {}
  for k, v in pairs(object) do result[copy_object(k)] = copy_object(v) end
  return result
end

local function update_save_slot_list()
  local entries = {}
  for i = 1, math.min(#save_data.patterns + 1, 999) do
    local entry
    if i <= #save_data.patterns then
      entry = save_data.patterns[i].name
    else
      entry = "-"
    end
    if i == last_edited_slot then entry = entry .. "*" end
    entries[i] = i .. ". " .. entry
  end
  save_slot_list.entries = entries
end

local function read_data()
  local disk_data = tab.load(DATA_FILE_PATH)
  if disk_data then
    if disk_data.version then
      if disk_data.version == 1 then
        save_data = disk_data
      else
        print("Unrecognized data, version " .. disk_data.version)
      end
    end
  end
  update_save_slot_list()
end

local function write_data()
  tab.save(save_data, DATA_FILE_PATH)
end

local function load_pattern(index)
  if index > #save_data.patterns then return end
  
  local pattern = copy_object(save_data.patterns[index])
    params:set("bpm", pattern.bpm)
    params:set("damping", pattern.damping)
    params:set("brightness", pattern.brightness)
    params:set("lpf_freq", pattern.lpf_freq)
    params:set("lpf_gain", pattern.lpf_gain)
    params:set("bpf_freq", pattern.bpf_freq)
    params:set("bpf_res", pattern.bpf_res)
    grid_display = pattern.grid_display
    root_num = pattern.root_num
    mode = pattern.mode
    pattern_len = pattern.pattern_len
    playchoice = pattern.playchoice
    steps = pattern.steps
    scale = pattern.scale
  
    tonic = music.note_num_to_name(root_num, 1)

  last_edited_slot = index
  update_save_slot_list()
  grid_dirty = true
end

local function save_pattern(index)
  local pattern = {
    name = os.date("%b %d %H:%M"),
    bpm = params:get("bpm"),
    amp = params:get("amp"),
    damping = params:get("damping"),
    brightness = params:get("brightness"),
    lpf_freq = params:get("lpf_freq"),
    lpf_gain = params:get("lpf_gain"),
    bpf_freq = params:get("bpf_freq"),
    bpf_res = params:get("bpf_res"),
    grid_display = grid_display,
    root_num = root_num,
    mode = mode,
    pattern_len = pattern_len,
    playchoice = playchoice,
    steps = steps,
    scale = scale
  }
  
  save_data.patterns[index] = copy_object(pattern)
  last_edited_slot = index
  update_save_slot_list()
  
  write_data()
end

local function delete_pattern(index)
  if index > 0 and index <= #save_data.patterns then
    table.remove(save_data.patterns, index)
    if index == last_edited_slot then
      last_edited_slot = 0
    elseif index < last_edited_slot then
      last_edited_slot = last_edited_slot - 1
    end
  end
  update_save_slot_list()
  
  write_data()
end


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
    
    if playmode[playchoice] == "Aft"  then
    	position = 17
    elseif playmode[playchoice] == "Sway"  then
    	position = 8
    else
    	position = 0
    end
    note_playing = nil
    beat_clock:reset()
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

    else -- random step position
        position = math.random(1,pattern_len)
    end

    if steps[position] ~= 0 then
        vel = math.random(1,100) / 100 -- random velocity values
        
          -- Audio engine out
        if params:get("output") == 1 or params:get("output") == 3 then
                engine.amp(vel)
                engine.hz(music.note_num_to_freq(scale[steps[position]]))
        end
        
            -- MIDI out
        if (params:get("output") == 2 or params:get("output") == 3) then
            if note_playing ~= nil then
                midi_out_device:note_off(note_playing,nil)
            end
            note_playing = music.freq_to_note_num(music.note_num_to_freq(scale[steps[position]]),1)
            midi_out_device:note_on(note_playing,vel*100)
        end
        
    end
    grid_dirty = true
end

-------------------------
-- handle grid presses --
-------------------------
 function grid_device.key(x,y,z)

    if z == 1 then
        if steps[x] == y then
            steps[x] = 0
        else
            steps[x] = y
        end
        grid_dirty = true
    end
    screen_dirty = true
end

---------------------
-- redraw the grid --
---------------------
function grid_redraw()
    grid_device:all(0)
    for i=1, pattern_len do
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
	
  if n==1 then
    alt = z==1
  end

  if z == 1 then
  
    if alt and n == 2 then 

    --random_notes()
    --grid_dirty = true

    --elseif n == 2 then
      steps = {}
      for i=1,16 do
        table.insert(steps,math.random(0,8))
      end

    elseif n == 2 then
      
      if confirm_message then
        confirm_message = nil
        confirm_function = nil
      end

    elseif n == 3 then
      if pages.index == 1 or pages.index == 2 then

        if k3_state == 0 then
          beat_clock:stop()
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
          beat_clock:start()
          k3_state = 0
        end

    
      -- Load/Save
      elseif pages.index == 3 then
          
        if confirm_message then
          confirm_function()
          confirm_message = nil
          confirm_function = nil

        else
          -- Load
          if save_menu_list.index == 1 then
            load_pattern(save_slot_list.index)
          
          -- Save
          elseif save_menu_list.index == 2 then
            if save_slot_list.index < #save_slot_list.entries then
              confirm_message = UI.Message.new({"Replace saved pattern?"})
              confirm_function = function() save_pattern(save_slot_list.index) end
            else
              save_pattern(save_slot_list.index)
            end
            
          -- Delete
          elseif save_menu_list.index == 3 then
            if save_slot_list.index < #save_slot_list.entries then
              confirm_message = UI.Message.new({"Delete saved pattern?"})
              confirm_function = function() delete_pattern(save_slot_list.index) end
            end
          end     
        end
      end
    end
	screen_dirty = true
  end
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
        
    if n == 2 then       -- scale
      mode = util.clamp(mode + delta, 1, #music.SCALES)
      scale = music.generate_scale_of_length(root_num,music.SCALES[mode].name,8)

    elseif n == 3 then	-- tonic
	        
      root_num = util.clamp(root_num + delta, 24, 96)
      tonic = music.note_num_to_name(root_num, 1)
      scale = music.generate_scale_of_length(root_num,music.SCALES[mode].name,8)
                
    end
        
        
  elseif pages.index == 2 then

    if alt and n == 2 then  
      -- pattern length
      pattern_len = util.clamp(pattern_len + delta, 2, 16)

		elseif n == 2 then           -- sequence direction
      playchoice = util.clamp(playchoice + delta, 1, #playmode)
    
    elseif alt and n == 3 then       

    elseif n == 3 then      -- tempo
      params:delta("bpm",delta)
            
    end
    

-- Load/Save
    elseif pages.index == 3 then
      
      if n == 2 then
        save_slot_list:set_index_delta(util.clamp(delta, -1, 1))
        
      elseif n == 3 then
        save_menu_list:set_index_delta(util.clamp(delta, -1, 1))
        
      end
        
  end
    
  screen_dirty = true
end

-------------------------
-- handle norns screen --
-------------------------
function redraw()
	
  screen.clear()
    
  if confirm_message then
    confirm_message:redraw()
    
  else
  
    pages:redraw()
    
    if beat_clock.playing then
      playback_icon.status = 1
    else
      playback_icon.status = 3
    end
    playback_icon:redraw()
    
    if pages.index == 1 then
	    
      screen.aa(1)
      screen.line_width(1)
      screen.move(63,10)
      screen.level(5)
      screen.text_center(name)
      screen.move(0,15)
      screen.line(127,15)
      screen.stroke()
      screen.move(0,50)
      screen.line(127,50)
      screen.stroke()

	    screen.move(0,30)
      screen.level(5)
      screen.text("Scale: ")
      screen.move(30,30)
      screen.level(15)
      screen.text(music.SCALES[mode].name)
      screen.move(0,40)
      screen.level(5)
      screen.text("Key: ")
      screen.move(30,40)
      screen.level(15)
      screen.text(tonic)

    elseif pages.index == 2 then      
	    
      screen.aa(1)
      screen.line_width(1)
      screen.move(63,10)
      screen.level(5)
      screen.text_center(name)
      screen.move(0,15)
      screen.line(127,15)
      screen.stroke()
      screen.move(0,50)
      screen.line(127,50)
      screen.stroke()

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
      if beat_clock.external then
      	screen.level(3)
        screen.text("External")
      else
      	screen.level(15)
        screen.text(params:get("bpm").." bpm")
      end
      screen.move(80,30)
      screen.level(5)
      screen.text("Len: ")
      screen.move(100,30)
      screen.level(15)
      screen.text(pattern_len)
                
    elseif pages.index == 3 then
	    
      save_slot_list:redraw()
      save_menu_list:redraw()

    end
  end  
  screen.update()
end


-----------
-- setup --
-----------
function init()
	
	screen.aa(1)
  
	-- initialize pattern with random notes
    for i=1,16 do
        table.insert(steps,math.random(0,8))
    end

	-- set clock functions
    beat_clock.on_step = handle_step
    beat_clock.on_stop = reset_pattern
    beat_clock.on_select_internal = function() beat_clock:start() end
    beat_clock.on_select_external = reset_pattern


  local screen_refresh_metro = metro.init()
  screen_refresh_metro.event = function()
    if screen_dirty then
      screen_dirty = false
      redraw()
    end
  end
  
  local grid_redraw_metro = metro.init()
  grid_redraw_metro.event = function()
    if grid_dirty and grid_device.device then
      grid_dirty = false
      grid_redraw()
    end
  end

	-- set up parameter menu

    params:add_number("bpm", "BPM", 1, 480, beat_clock.bpm)
    params:set_action("bpm", function(x) beat_clock:bpm_change(x) end)
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

	params:add_option("grid_rotation", "Grid Rotation", grid_display_options)
	params:set_action("grid_rotation", function(x) 
      local val
      if x == 1 then val = 0 else val = 2 end
		grid_device:all(0)
		grid_device:rotation(val)
		grid_device:refresh()
	end) 

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
    
  	params:add_option("clock", "Clock Source", {"Internal", "External"}, beat_clock.external or 2 and 1)
	params:set_action("clock", function(x) beat_clock:clock_source_change(x) end)
	
	params:add{type = "option", id = "clock_out", name = "Clock Out", options = {"Off", "On"}, default = beat_clock.send or 2 and 1,
    	action = function(value)
		if value == 1 then beat_clock.send = false
		else beat_clock.send = true end
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
    	beat_clock:process_midi(data)
		if not beat_clock.playing then
			screen_dirty = true
    	end
	end
    
	-- Init UI
  pages = UI.Pages.new(1, 3)
  save_slot_list = UI.ScrollingList.new(5, 9, 1, {})
  save_slot_list.num_visible = 4
  save_menu_list = UI.List.new(92, 20, 1, save_menu_items)
  playback_icon = UI.PlaybackIcon.new(121, 55)
  
  screen.aa(1)

  screen_refresh_metro:start(1 / SCREEN_FRAMERATE)
  grid_redraw_metro:start(1 / GRID_FRAMERATE)

	beat_clock:start()
        
    --h.init()

  -- Data
  read_data()
end


function cleanup ()
  beat_clock:stop()
end
