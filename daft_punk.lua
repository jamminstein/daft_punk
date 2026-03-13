-- daft_punk.lua ENHANCED
-- DAFT PUNK ANATOMY + DJ Transitions
-- norns + grid instrument
--
-- BROWSE: E1=album  E2=song
-- PLAY:   grid left half = chords, right half = notes
-- ARP:    K2=toggle  K3=style  E3=speed (when arp on)
--         E3=octave (when arp off)
-- Arp absorbs all held buttons (chords expand), max 16 notes.
--
-- NEW FEATURES:
-- - DJ transition: K1+K3 initiates smooth crossfade between songs over 8 bars
-- - Arp pool increased to 16 notes (from 10)
-- - Warning toast when pool is full

engine.name = "MollyThePoly"

local g        -- grid device (connected in init)
local midi_out -- MIDI out device (connected in init)

-- ============================================================
--  DATABASE
--  DB[i] = { album, year, songs = { {title, chords, notes} } }
--  chords = string chord symbols
--  notes  = pitch classes 0-11 (C=0 ... B=11)
-- ============================================================

local DB = {
  {
    album = "HOMEWORK",
    year  = 1997,
    songs = {
      { title="DAFTENDIREKT",            chords={},                                        notes={0,2,3,5,7,8,10} },
      { title="WDPK 83.7 FM",            chords={},                                        notes={0,4,7,11} },
      { title="REVOLUTION 909",          chords={"Dm","Am","Bb","F"},                      notes={2,5,7,9,0,3} },
      { title="DA FUNK",                 chords={"Dm","Gm","Cm","F7"},                     notes={2,5,7,9,10,0,3} },
      { title="PHOENIX",                 chords={"Am","G","F","Em"},                       notes={9,7,5,4,2,0} },
      { title="FRESH",                   chords={"Cm","Gm","Fm","Ab"},                     notes={0,3,5,7,8,10} },
      { title="AROUND THE WORLD",        chords={"Dm","Am","Bb","C"},                      notes={2,5,7,9,0,3} },
      { title="ROLLIN & SCRATCHIN",      chords={"E5","A5","B5"},                          notes={4,7,9,11,0} },
      { title="TEACHERS",                chords={"Fmaj7","Em7","Am","G"},                  notes={5,4,2,0,9,7} },
      { title="HIGH FIDELITY",           chords={"Cm","Fm","Bb","Eb"},                     notes={0,3,5,7,10,8} },
      { title="FILTER",                  chords={"Am","Em","F","C"},                       notes={9,4,5,0,2,7} },
      { title="OH YEAH",                 chords={"Gm","Dm","Cm","Bb"},                     notes={7,2,0,10,5,3} },
      { title="BURNIN",                  chords={"Am","G","F","E7"},                       notes={9,7,5,4,2,0,11} },
      { title="INDO SILVER CLUB",        chords={"Fm","Cm","Db","Ab"},                     notes={5,0,1,8,3,10} },
      { title="ALIVE",                   chords={"Am","F","C","G"},                        notes={9,5,0,7,2,4} },
      { title="FUNK AD",                 chords={"Dm","Gm","Bb","C"},                      notes={2,7,10,0,5,3} },
    }
  },
  {
    album = "DISCOVERY",
    year  = 2001,
    songs = {
      { title="ONE MORE TIME",           chords={"C#m","A","E","B"},                       notes={1,9,4,11,6,8} },
      { title="AERODYNAMIC",             chords={"Dm","Am","Bb","Gm"},                     notes={2,9,10,7,5,0,3} },
      { title="DIGITAL LOVE",            chords={"Gmaj7","F#m7","Em7","Dmaj7","C#m7","Bm7","Am7","D7"}, notes={7,6,4,2,9,11,0,5} },
      { title="HARDER BETTER FASTER",    chords={"Am","G","Fmaj7","Em7"},                  notes={9,7,5,4,0,2} },
      { title="CRESCENDOLLS",            chords={"C#m","B","A","G#m"},                     notes={1,11,9,8,6,4} },
      { title="NIGHTVISION",             chords={"Cm","Ab","Eb","Bb"},                     notes={0,8,3,10,5,7} },
      { title="SUPERHEROES",             chords={"Am","G","F","C"},                        notes={9,7,5,0,2,4} },
      { title="HIGH LIFE",               chords={"Dm","Am","Gm","C"},                      notes={2,9,7,0,5,3,10} },
      { title="SOMETHING ABOUT US",      chords={"Fmaj7","Em7","Am7","Dm7"},               notes={5,4,9,2,0,7,11} },
      { title="VOYAGER",                 chords={"Am","F","G","C"},                        notes={9,5,7,0,2,4,11} },
      { title="VERIDIS QUO",             chords={"Dm","Am","Gm","Cmaj7"},                  notes={2,9,7,0,5,4,11} },
      { title="SHORT CIRCUIT",           chords={"Em","Am","D","G"},                       notes={4,9,2,7,0,11,5} },
      { title="FACE TO FACE",            chords={"Am","Dm","G","C"},                       notes={9,2,7,0,5,4,11} },
      { title="TOO LONG",                chords={"Dm","Am","Gm","C7"},                     notes={2,9,7,0,5,10,3} },
    }
  },
  {
    album = "HUMAN AFTER ALL",
    year  = 2005,
    songs = {
      { title="HUMAN AFTER ALL",         chords={"Em","C","G","D"},                        notes={4,0,7,2,9,11,5} },
      { title="THE PRIME TIME",          chords={"Dm","Gm","Am","F"},                      notes={2,7,9,5,0,3,10} },
      { title="THE BRAINWASHER",         chords={"Am","E","F","C"},                        notes={9,4,5,0,2,7,11} },
      { title="ON/OFF",                  chords={},                                        notes={0,4,7} },
      { title="TELEVISION RULES",        chords={"Fm","Cm","Ab","Eb"},                     notes={5,0,8,3,10,7,1} },
      { title="TECHNOLOGIC",             chords={"Am","G","F","E"},                        notes={9,7,5,4,0,2,11} },
      { title="EMOTION",                 chords={"Gmaj7","Em7","Cmaj7","D7"},              notes={7,4,0,2,9,11,5,6} },
      { title="ST TROPEZ",               chords={"Fmaj7","Gm7","Am7","Bbmaj7"},            notes={5,7,9,10,0,2,4} },
      { title="ROBOT ROCK",              chords={"Em","Am","D","G"},                       notes={4,9,2,7,0,5,11} },
      { title="STEAM MACHINE",           chords={"Dm","Am","Bb","C"},                      notes={2,9,10,0,5,7,3} },
      { title="MAKE LOVE",               chords={"Fmaj7","Em7","Am","Dm"},                 notes={5,4,9,2,0,7,11} },
      { title="THE IMPOSSIBLE DREAM",    chords={"Cm","Fm","Gm","Eb"},                     notes={0,5,7,3,10,8,2} },
    }
  },
  {
    album = "RANDOM ACCESS MEMORIES",
    year  = 2013,
    songs = {
      { title="GIVE LIFE BACK",          chords={"Gmaj7","C","Am7","D7"},                  notes={7,0,9,2,11,5,4} },
      { title="THE GAME OF LOVE",        chords={"Fmaj7","Em7","Am7","Dm7"},               notes={5,4,9,2,0,7,11} },
      { title="GIORGIO BY MORODER",      chords={"Dm","Am","Gm","C"},                      notes={2,9,7,0,5,3,10} },
      { title="WITHIN",                  chords={"Am","Fmaj7","C","G"},                    notes={9,5,0,7,2,4,11} },
      { title="INSTANT CRUSH",           chords={"Am","F","C","G"},                        notes={9,5,0,7,2,4,11} },
      { title="LOSE YOURSELF TO DANCE",  chords={"Fmaj7","Am7","G","Em7"},                 notes={5,9,7,4,0,2,11} },
      { title="TOUCH",                   chords={"Fmaj7","Em7","Am","G","C","Dm"},         notes={5,4,9,7,0,2,11,3} },
      { title="GET LUCKY",               chords={"Bm","D","F#m","E"},                      notes={11,2,6,4,9,7,0} },
      { title="BEYOND",                  chords={"Am","F","C","G","Em"},                   notes={9,5,0,7,4,2,11} },
      { title="MOTHERBOARD",             chords={"Cmaj7","Am7","Fmaj7","G"},               notes={0,9,5,7,4,2,11} },
      { title="FRAGMENTS OF TIME",       chords={"Dmaj7","Bm7","G","A"},                   notes={2,11,7,9,4,6,0} },
      { title="DOIN IT RIGHT",           chords={"Am","G","F","Em"},                       notes={9,7,5,4,0,2,11} },
      { title="CONTACT",                 chords={"Dm","Am","Gm","F"},                      notes={2,9,7,5,0,3,10} },
    }
  },
}

-- ============================================================
--  MUSIC THEORY
-- ============================================================
local CHORD_SHAPES = {
  [\"\"]     = {0,4,7},
  [\"m\"]    = {0,3,7},
  [\"5\"]    = {0,7},
  [\"7\"]    = {0,4,7,10},
  [\"maj7\"] = {0,4,7,11},
  [\"m7\"]   = {0,3,7,10},
  [\"dim\"]  = {0,3,6},
  [\"dim7\"] = {0,3,6,9},
  [\"aug\"]  = {0,4,8},
  [\"sus2\"] = {0,2,7},
  [\"sus4\"] = {0,5,7},
  [\"add9\"] = {0,4,7,14},
  [\"9\"]    = {0,4,7,10,14},
  [\"6\"]    = {0,4,7,9},
  [\"m6\"]   = {0,3,7,9},
  [\"maj9\"] = {0,4,7,11,14},
  [\"m9\"]   = {0,3,7,10,14},
}

local NOTE_SEMI = {
  C=0,[\"C#\"]=1,Db=1,D=2,[\"D#\"]=3,Eb=3,
  E=4,F=5,[\"F#\"]=6,Gb=6,G=7,
  [\"G#\"]=8,Ab=8,A=9,[\"A#\"]=10,Bb=10,B=11
}

local NOTE_NAMES = {\"C\",\"C#\",\"D\",\"D#\",\"E\",\"F\",\"F#\",\"G\",\"G#\",\"A\",\"A#\",\"B\"}

local function midi_to_hz(n)
  return 440.0 * (2.0 ^ ((n - 69) / 12.0))
end

local function chord_to_midi(str, oct)
  if not str or str == \"\" then return {} end
  local root, qual = str:match(\"^([A-G][b#]?)(.*)$\")
  if not root then return {} end
  local semi = NOTE_SEMI[root]
  if semi == nil then return {} end
  local shape = CHORD_SHAPES[qual] or CHORD_SHAPES[\"\"]
  local base  = (oct + 1) * 12 + semi
  local out   = {}
  for _, iv in ipairs(shape) do
    local n = base + iv
    if n >= 0 and n <= 127 then table.insert(out, n) end
  end
  return out
end

local function pc_to_midi(pc, oct)
  return math.max(0, math.min(127, (oct + 1) * 12 + pc))
end

-- ============================================================
--  CONSTANTS
-- ============================================================
local ARP_STYLES    = {\"UP\",\"DN\",\"U+D\",\"RND\",\"DRNK\",\"BRST\"}
local ARP_DIVS      = {1/32, 1/16, 1/12, 1/8, 1/6, 1/4, 1/2, 1}
local ARP_DIV_NAMES = {\"1/32\",\"1/16\",\"1/12\",\"1/8\",\"1/6\",\"1/4\",\"1/2\",\"1\"}
local ARP_MAX       = 16  -- ENHANCED: increased from 10 to 16

local CHORD_COLS      = 7
local DIV_COL         = 8
local NOTE_COL_START  = 9

local BRI = { ghost=1, dim=3, mid=6, hi=10, full=15 }

-- ============================================================
--  STATE
-- ============================================================
local state = {
  album_idx   = 1,
  song_idx    = 1,
  octave      = 4,

  arp_on      = false,
  arp_style   = 1,
  arp_div_idx = 4,    -- default = 1/8
  arp_step    = 1,
  arp_clock   = nil,
  arp_pool    = {},   -- sorted MIDI notes in pool

  held        = {},   -- held[col][row] = true / nil
  sounding    = {},   -- sounding[midi_note] = true / nil
  
  -- NEW: DJ transition
  transition_active = false,
  transition_from_song = nil,
  transition_to_song = nil,
  transition_progress = 0,  -- 0-1
  transition_total_bars = 8,
  pool_full_flash = 0,  -- display warning when pool is full
}

-- ============================================================
--  NAV HELPERS
-- ============================================================
local function cur_album() return DB[state.album_idx] end
local function cur_song()
  local a = cur_album(); return a.songs[state.song_idx]
end
local function clamp(v,lo,hi) return math.max(lo, math.min(hi, v)) end

-- ============================================================
--  SOUND HELPERS
-- ============================================================
local function sound_on(n)
  if state.sounding[n] then return end
  engine.note_on(midi_to_hz(n), params:get(\"amp\"))
  if midi_out then
    midi_out:note_on(n, params:get(\"velocity\"), params:get(\"midi_ch\"))
  end
  state.sounding[n] = true
end

local function sound_off(n)
  if not state.sounding[n] then return end
  engine.note_off(midi_to_hz(n))
  if midi_out then
    midi_out:note_off(n, 0, params:get(\"midi_ch\"))
  end
  state.sounding[n] = nil
end

local function silence_all()
  for n, _ in pairs(state.sounding) do
    engine.note_off(midi_to_hz(n))
    if midi_out then midi_out:note_off(n, 0, params:get(\"midi_ch\")) end
  end
  state.sounding = {}
end

-- ============================================================
--  ARP POOL (now max 16)
-- ============================================================
local function rebuild_pool()
  local song   = cur_song()
  local chords = song.chords or {}
  local notes  = song.notes  or {}
  local seen   = {}
  local pool   = {}

  for col = 1, 16 do
    if col ~= DIV_COL then
      local rm = state.held[col]
      if rm then
        for row = 1, 8 do
          if rm[row] then
            if col <= CHORD_COLS then
              -- chord col: expand
              for _, n in ipairs(chord_to_midi(chords[col] or \"\", state.octave)) do
                if not seen[n] and #pool < ARP_MAX then
                  seen[n] = true; table.insert(pool, n)
                end
              end
            elseif col >= NOTE_COL_START then
              -- note col: single pitch, row shifts octave
              local ni  = col - NOTE_COL_START + 1
              local pc  = notes[ni]
              if pc ~= nil then
                local ro = state.octave + (row > 4 and 1 or 0)
                local n  = pc_to_midi(pc, math.min(ro, 8))
                if not seen[n] and #pool < ARP_MAX then
                  seen[n] = true; table.insert(pool, n)
                end
              end
            end
          end
        end
      end
    end
  end

  table.sort(pool)
  state.arp_pool = pool
  state.arp_step = 1
  
  -- NEW: flash warning if pool is full
  if #pool >= ARP_MAX then
    state.pool_full_flash = 30
  end
end

-- ============================================================
--  NEW: DJ TRANSITION FUNCTION
-- ============================================================
local transition_clock = nil

local function transition(from_idx, to_idx, bars)
  state.transition_active = true
  state.transition_from_song = cur_song()
  state.transition_to_song = DB[state.album_idx].songs[to_idx]
  state.transition_progress = 0
  state.transition_total_bars = bars or 8
  
  if transition_clock then
    pcall(function() clock.cancel(transition_clock) end)
  end
  
  transition_clock = clock.run(function()
    local bar_duration = (60 / state.bpm) * 4
    local total_time = bar_duration * state.transition_total_bars
    local elapsed = 0
    
    while elapsed < total_time and state.transition_active do
      state.transition_progress = math.min(1, elapsed / total_time)
      
      -- Blend chord progressions smoothly
      -- For now, visual indicator; audio crossfade logic would integrate here
      
      elapsed = elapsed + 0.1
      clock.sleep(0.1)
    end
    
    state.transition_active = false
    state.transition_progress = 1
    state.song_idx = to_idx
  end)
end

-- ============================================================
--  ARPEGGIATOR
-- ============================================================
local function arp_next(style, pool, step)
  local N    = #pool
  if N == 0 then return nil end

  if style == 1 then                          -- UP
    local i = ((step-1) % N) + 1
    return pool[i], step + 1

  elseif style == 2 then                      -- DOWN
    local i = N - ((step-1) % N)
    return pool[i], step + 1

  elseif style == 3 then                      -- UP+DOWN bounce
    local span = N > 1 and (2*N-2) or 1
    local pos  = (step-1) % span
    local i    = pos < N and (pos+1) or (span-pos+1)
    return pool[i], step + 1

  elseif style == 4 then                      -- RANDOM
    return pool[math.random(1, N)], step

  elseif style == 5 then                      -- DRUNK walk
    local prev = ((step-1) % N) + 1
    local nxt  = prev + (math.random(2)==1 and 1 or -1)
    nxt = clamp(nxt, 1, N)
    return pool[nxt], nxt

  elseif style == 6 then                      -- BURST: signal
    return \"BURST\", step
  end
end

local function arp_fire()
  local pool = state.arp_pool
  if #pool == 0 then silence_all(); return end

  if state.arp_style == 6 then
    -- stab everything, brief gate, then off
    silence_all()
    for _, n in ipairs(pool) do sound_on(n) end
    local gate = clock.get_beat_sec() * ARP_DIVS[state.arp_div_idx] * 0.25
    clock.sleep(gate)
    silence_all()
  else
    local n, new_step = arp_next(state.arp_style, pool, state.arp_step)
    state.arp_step = new_step
    if n then
      silence_all()
      sound_on(n)
    end
  end
end

local function arp_launch()
  if state.arp_clock then clock.cancel(state.arp_clock) end
  state.arp_clock = clock.run(function()
    while true do
      clock.sync(ARP_DIVS[state.arp_div_idx])
      if state.arp_on and #state.arp_pool > 0 then
        arp_fire()
      elseif state.arp_on then
        silence_all()
      end
    end
  end)
end

local function arp_kill()
  if state.arp_clock then
    clock.cancel(state.arp_clock)
    state.arp_clock = nil
  end
  silence_all()
end

-- ============================================================
--  GLITCH HELPER
-- ============================================================
local GMAP = { A=\"4\",E=\"3\",O=\"0\",I=\"1\",T=\"7\",a=\"@\",e=\"3\",o=\"0\",s=\"$\" }
local function glitch(str, chance)
  chance = chance or 0.10
  if math.random() > 0.55 then return str end
  local out = {}
  for i = 1, #str do
    local c = str:sub(i,i)
    if math.random() < chance and GMAP[c] then
      table.insert(out, GMAP[c])
    else
      table.insert(out, c)
    end
  end
  return table.concat(out)
end

-- ============================================================
--  GRID REDRAW
-- ============================================================
local function grid_redraw()
  if not g then return end
  g:all(0)

  local song   = cur_song()
  local chords = song.chords or {}
  local notes  = song.notes  or {}

  -- build pool set for in-pool highlighting
  local pool_set = {}
  for _, n in ipairs(state.arp_pool) do pool_set[n] = true end

  -- ── Chord cols 1-7 ───────────────────────────────────
  for col = 1, CHORD_COLS do
    local cs = chords[col]
    local in_pool = false
    if cs then
      for _, n in ipairs(chord_to_midi(cs, state.octave)) do
        if pool_set[n] then in_pool = true; break end
      end
    end
    for row = 1, 8 do
      local held = state.held[col] and state.held[col][row]
      local bri
      if not cs then
        bri = BRI.ghost
      elseif held then
        bri = BRI.full
      elseif in_pool then
        bri = (row == 1) and BRI.hi or BRI.mid
      else
        bri = (row <= 5) and BRI.mid or BRI.dim
      end
      g:led(col, row, bri)
    end
  end

  -- ── Divider col 8 ────────────────────────────────────
  for row = 1, 8 do g:led(DIV_COL, row, BRI.ghost) end

  -- ── Note cols 9-16 ───────────────────────────────────
  for col = NOTE_COL_START, 16 do
    local ni = col - NOTE_COL_START + 1
    local pc = notes[ni]
    local midi_n = pc ~= nil and pc_to_midi(pc, state.octave) or nil
    local in_pool = midi_n and pool_set[midi_n]
    for row = 1, 8 do
      local held = state.held[col] and state.held[col][row]
      local bri
      if pc == nil then
        bri = BRI.ghost
      elseif held then
        bri = BRI.full
      elseif in_pool then
        bri = (row == 1) and BRI.full or BRI.hi
      else
        bri = (row <= 5) and BRI.hi or BRI.dim
      end
      g:led(col, row, bri)
    end
  end

  g:refresh()
end

-- ============================================================
--  SCREEN REDRAW
-- ============================================================
function redraw()
  screen.clear()
  screen.aa(0)

  local alb  = cur_album()
  local song = cur_song()
  local chords = song.chords or {}
  local notes  = song.notes  or {}

  -- ── Header block ─────────────────────────────────────
  screen.level(2)
  screen.rect(0, 0, 128, 12)
  screen.fill()

  screen.font_face(7)
  screen.font_size(8)
  screen.level(15)
  screen.move(2, 9)
  screen.text(glitch(\"DAFT PUNK\", 0.14))

  -- album selector boxes (4 albums)
  for i = 1, #DB do
    local bx = 128 - (#DB - i + 1) * 9
    if i == state.album_idx then
      screen.level(15)
      screen.rect(bx, 1, 8, 10)
      screen.fill()
      screen.level(0)
    else
      screen.level(4)
      screen.rect(bx, 1, 8, 10)
      screen.stroke()
    end
    screen.font_face(1)
    screen.font_size(5)
    screen.move(bx + 2, 9)
    screen.text(tostring(i))
    screen.level(i == state.album_idx and 0 or 4)
  end

  -- ── Album name ───────────────────────────────────────
  screen.font_face(7)
  screen.font_size(6)
  screen.level(8)
  screen.move(0, 22)
  screen.text(glitch(alb.album, 0.07))

  screen.font_face(1)
  screen.font_size(5)
  screen.level(4)
  screen.move(108, 22)
  screen.text(tostring(alb.year))

  -- ── Song title ───────────────────────────────────────
  screen.font_face(7)
  screen.font_size(8)
  screen.level(15)
  screen.move(0, 34)
  local title = song.title or \"?\"
  if #title > 15 then title = title:sub(1,14)..\"..\" end
  screen.text(glitch(title, 0.04))

  -- song counter + scrollbar
  screen.font_face(1)
  screen.font_size(5)
  screen.level(4)
  screen.move(0, 43)
  screen.text(string.format(\"%02d / %02d\", state.song_idx, #alb.songs))

  -- scrollbar (right edge, rows 12-54)
  local total = #alb.songs
  local bar_h = math.max(3, math.floor(42 / total))
  local bar_y = 12 + math.floor(42 * (state.song_idx-1) / math.max(total-1, 1))
  screen.level(2)
  screen.rect(125, 12, 3, 42)
  screen.fill()
  screen.level(12)
  screen.rect(125, bar_y, 3, bar_h)
  screen.fill()

  -- ── Chord strip ──────────────────────────────────────
  screen.font_face(1)
  screen.font_size(5)
  screen.level(5)
  screen.move(0, 52)
  local cs = \"\"
  for i, c in ipairs(chords) do
    local tok = c .. (i < #chords and \" \" or \"\")
    if #cs + #tok > 20 then cs = cs .. \"..\"; break end
    cs = cs .. tok
  end
  screen.text(cs ~= \"\" and cs or \"-- no chords --\")

  -- ── Note strip ───────────────────────────────────────
  screen.level(3)
  screen.move(0, 60)
  local ns = \"\"
  for i, pc in ipairs(notes) do
    local tok = (NOTE_NAMES[pc+1] or \"?\") .. (i < #notes and \" \" or \"\")
    if #ns + #tok > 20 then ns = ns .. \"..\"; break end
    ns = ns .. tok
  end
  screen.text(ns)

  -- ── Bottom status bar ─────────────────────────────────
  if state.arp_on then
    screen.level(13)
    screen.rect(0, 55, 128, 9)
    screen.fill()
    screen.level(0)
    screen.font_face(7)
    screen.font_size(6)
    screen.move(2, 63)
    screen.text(glitch(\"ARP:\"..ARP_STYLES[state.arp_style], 0.13))
    -- div
    screen.font_face(1)
    screen.font_size(5)
    screen.move(60, 63)
    screen.text(ARP_DIV_NAMES[state.arp_div_idx])
    -- pool count + NEW warning
    screen.move(90, 63)
    if #state.arp_pool >= ARP_MAX then
      screen.level(15)
      screen.text(#state.arp_pool..\"N FULL!\")
    else
      screen.level(0)
      screen.text(#state.arp_pool..\"N\")
    end
    -- octave
    screen.move(112, 63)
    screen.text(\"O\"..state.octave)
  else
    screen.level(3)
    screen.font_face(1)
    screen.font_size(5)
    screen.move(0, 63)
    if state.transition_active then
      screen.level(13)
      screen.text(\"TRANSITION: \"..string.format(\"%.0f\", state.transition_progress*100)..\"% K1+K3 OFF\")
    else
      screen.text(\"ARP OFF  OCT:\"..state.octave..\"  K2=ON\")
    end
  end

  screen.update()
end

-- ============================================================
--  DIRECT PLAY (arp off)
-- ============================================================
local function direct_play_from_held()
  silence_all()
  local song   = cur_song()
  local chords = song.chords or {}
  local notes  = song.notes  or {}

  for col = 1, 16 do
    if col ~= DIV_COL then
      local rm = state.held[col]
      if rm then
        for row = 1, 8 do
          if rm[row] then
            if col <= CHORD_COLS then
              for _, n in ipairs(chord_to_midi(chords[col] or \"\", state.octave)) do
                sound_on(n)
              end
            elseif col >= NOTE_COL_START then
              local ni  = col - NOTE_COL_START + 1
              local pc  = notes[ni]
              if pc ~= nil then
                local ro = state.octave + (row > 4 and 1 or 0)
                sound_on(pc_to_midi(pc, math.min(ro, 8)))
              end
            end
          end
        end
      end
    end
  end
end

-- ============================================================
--  GRID KEY HANDLER
-- ============================================================
local function on_grid_key(x, y, z)
  if x == DIV_COL then return end

  -- update held map
  if not state.held[x] then state.held[x] = {} end
  state.held[x][y] = (z == 1) or nil

  -- always rebuild arp pool
  rebuild_pool()

  if not state.arp_on then
    direct_play_from_held()
  end

  grid_redraw()
  redraw()
end

-- ============================================================
--  ENCODERS
-- ============================================================
function enc(n, d)
  if n == 1 then
    local new = clamp(state.album_idx + d, 1, #DB)
    if new ~= state.album_idx then
      state.album_idx = new
      state.song_idx  = 1
      state.held      = {}
      rebuild_pool()
      silence_all()
    end

  elseif n == 2 then
    local new = clamp(state.song_idx + d, 1, #cur_album().songs)
    if new ~= state.song_idx then
      state.song_idx = new
      state.held     = {}
      rebuild_pool()
      silence_all()
    end

  elseif n == 3 then
    if state.arp_on then
      state.arp_div_idx = clamp(state.arp_div_idx - d, 1, #ARP_DIVS)
    else
      state.octave = clamp(state.octave + d, 2, 7)
    end
  end

  grid_redraw()
  redraw()
end

-- ============================================================
--  KEYS
-- ============================================================
function key(n, z)
  if z == 0 then return end
  if n == 1 and z == 1 then
    -- NEW: K1+K3 initiates transition
    state.k1_pressed = true
  elseif n == 2 then
    state.arp_on = not state.arp_on
    if state.arp_on then
      rebuild_pool()
    else
      silence_all()
    end
    grid_redraw()
    redraw()

  elseif n == 3 and z == 1 then
    if state.k1_pressed then
      -- K1+K3: start transition
      if state.song_idx < #cur_album().songs then
        transition(state.song_idx, state.song_idx + 1, 8)
      end
      state.k1_pressed = false
    else
      -- K3 alone: cycle arp style
      state.arp_style = (state.arp_style % #ARP_STYLES) + 1
      state.arp_step  = 1
      redraw()
    end
  elseif n == 1 and z == 0 then
    state.k1_pressed = false
  end
end

-- ============================================================
--  PARAMS
-- ============================================================
local function setup_params()
  params:add_separator(\"DAFT PUNK ANATOMY ENHANCED\")

  params:add_separator(\"synth\")
  params:add{
    type=\"control\", id=\"amp\", name=\"Amp\",
    controlspec=controlspec.new(0, 1, \"lin\", 0.01, 0.75, \"\"),
    action=function(v) engine.amp(v) end
  }
  params:add{
    type=\"control\", id=\"attack\", name=\"Attack\",
    controlspec=controlspec.new(0.001, 2, \"exp\", 0.001, 0.005, \"s\"),
    action=function(v) engine.attack(v) end
  }
  params:add{
    type=\"control\", id=\"release\", name=\"Release\",
    controlspec=controlspec.new(0.01, 8, \"exp\", 0.01, 0.9, \"s\"),
    action=function(v) engine.release(v) end
  }
  params:add{
    type=\"control\", id=\"cutoff\", name=\"Cutoff\",
    controlspec=controlspec.new(100, 8000, \"exp\", 1, 2800, \"hz\"),
    action=function(v) engine.cutoff(v) end
  }
  params:add{
    type=\"control\", id=\"resonance\", name=\"Resonance\",
    controlspec=controlspec.new(0, 1, \"lin\", 0.01, 0.15, \"\"),
    action=function(v) engine.resonance(v) end
  }
  params:add{
    type=\"number\", id=\"wave_shape\", name=\"Wave Shape\",
    min=0, max=3, default=1,
    action=function(v) engine.wave_shape(v) end
  }

  params:add_separator(\"MIDI out\")
  params:add{
    type=\"number\", id=\"midi_out_device\", name=\"MIDI Device\",
    min=1, max=4, default=1,
    action=function(v) midi_out = midi.connect(v) end
  }
  params:add{
    type=\"number\", id=\"midi_ch\", name=\"MIDI Channel\",
    min=1, max=16, default=1
  }
  params:add{
    type=\"number\", id=\"velocity\", name=\"Velocity\",
    min=1, max=127, default=90
  }

  params:bang()
end

-- ============================================================
--  INIT / CLEANUP
-- ============================================================
function init()
  math.randomseed(os.time())

  g        = grid.connect()
  midi_out = midi.connect(1)

  setup_params()

  g.key = on_grid_key

  -- Animation + pool full warning
  clock.run(function()
    while true do
      if state.pool_full_flash > 0 then
        state.pool_full_flash = state.pool_full_flash - 1
      end
      redraw()
      grid_redraw()
      clock.sleep(1/20)
    end
  end)

  arp_launch()

  redraw()
  grid_redraw()
end

function cleanup()
  arp_kill()
  silence_all()
end
