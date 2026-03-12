-- hbf.lua
-- HARDER BETTER FASTER
-- Daft Punk Acid Bass · Roulette Grid · Hi-Res Helmet Visualiser
-- requires: Norns + Grid (optimised for 16×8)
-- engine: PolyPerc (built-in)
--
-- CONTROLS
-- grid [1,1]  = PLAY
-- grid [1,2]  = STOP
-- grid rest   = roulette (reshuffled every boot)
-- E1          = BPM
-- E2          = root note (C2–C4)
-- E3          = filter cutoff
-- K2          = play / stop toggle
-- K3          = randomise synth patch

engine.name = "PolyPerc"


--------------------------------------------------------------------------------
-- SCALES
--------------------------------------------------------------------------------

local SCALES = {
  acid       = {0,2,3,5,7,8,10},
  phrygian   = {0,1,3,5,7,8,10},
  dorian     = {0,2,3,5,7,9,10},
  pentatonic = {0,3,5,7,10},
  wholetone  = {0,2,4,6,8,10},
}
local SCALE_NAMES = {"acid","phrygian","dorian","pentatonic","wholetone"}

--------------------------------------------------------------------------------
-- CHORD VOICINGS
--------------------------------------------------------------------------------

local CHORDS = {
  root   = {0},
  power  = {0,7},
  minor  = {0,3,7},
  major  = {0,4,7},
  dim    = {0,3,6},
  sus4   = {0,5,10},
  octave = {0,12},
}
local CHORD_NAMES = {"root","power","minor","major","dim","sus4","octave"}

--------------------------------------------------------------------------------
-- ARP PATTERNS
--------------------------------------------------------------------------------

local PATTERNS = {
  {1,2,3,4},
  {1,3,2,4},
  {1,1,2,3},
  {1,2,1,3,1,4},
  {4,3,2,1},
  {1,1,1,2,3},
  {1,2,3,2},
  {1,3,1,4,2,4},
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local s = {
  playing      = false,
  bpm          = 128,
  root_midi    = 36,
  scale        = "acid",
  chord        = "root",
  pat_idx      = 1,
  step         = 1,
  octave_shift = 0,
  pitch_bend   = 0,
  gate         = 0.8,
  velocity     = 0.8,
  swing        = 0,
  chorus       = false,
  minimal      = false,
  distort      = false,
  stutter      = false,
  stutter_div  = 1,
  glide        = false,
  skip         = false,
  cascade      = false,
  vel_ramp     = 0,
  vel_ramp_step= 0,
  cutoff       = 2000,
  pw           = 0.5,
  rel          = 0.3,
  amp          = 0.8,
}

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

local function rnd(t)
  return t[math.random(#t)]
end

local function reset_fx()
  s.stutter      = false
  s.stutter_div  = 1
  s.chorus       = false
  s.minimal      = false
  s.distort      = false
  s.glide        = false
  s.skip         = false
  s.cascade      = false
  s.pitch_bend   = 0
  s.octave_shift = 0
  s.vel_ramp     = 0
  s.swing        = 0
  s.gate         = 0.8
  s.velocity     = 0.8
end

local function apply_patch()
  engine.cutoff(s.cutoff)
  engine.pw(s.pw)
  engine.release(s.rel)
  engine.amp(s.amp)
end

local function randomise_patch()
  s.cutoff = rnd({400,800,1200,2000,3500,6000,8000})
  s.pw     = math.random() * 0.7 + 0.1
  s.rel    = rnd({0.05,0.1,0.2,0.4,0.7,1.2})
  s.amp    = math.random() * 0.5 + 0.5
  apply_patch()
end

--------------------------------------------------------------------------------
-- AUDIO
--------------------------------------------------------------------------------

local prev_hz = 0

local function midi_to_hz(m)
  return 440.0 * (2.0 ^ ((m - 69.0) / 12.0))
end

local function scale_note(degree)
  local sc  = SCALES[s.scale]
  local len = #sc
  local oct = math.floor((degree - 1) / len)
  local idx = ((degree - 1) % len) + 1
  return s.root_midi + oct * 12 + sc[idx] + s.octave_shift * 12 + s.pitch_bend
end

local function play_note(midi, vel, dur)
  local hz = midi_to_hz(midi)
  if s.distort then
    hz = hz * (1.0 + (math.random() * 0.04 - 0.02))
  end
  local cut = s.chorus and clamp(s.cutoff * 1.5, 100, 8000) or s.cutoff
  engine.cutoff(cut)
  engine.gain(clamp(vel * (s.chorus and 1.3 or 1.0), 0, 1))
  engine.release(dur * 0.6)
  engine.pw(s.pw)
  if s.glide and prev_hz > 0 then
    local start_hz = prev_hz
    local steps    = 8
    clock.run(function()
      for i = 1, steps do
        local t = i / steps
        engine.hz(start_hz + (hz - start_hz) * t)
        clock.sleep(dur / steps)
      end
    end)
  else
    engine.hz(hz)
  end
  prev_hz = hz
end

--------------------------------------------------------------------------------
-- SEQUENCER
--------------------------------------------------------------------------------

local seq_id = nil

local function step_sec()
  local base = 60.0 / s.bpm / 4.0
  return base / (s.stutter and s.stutter_div or 1)
end

local function advance()
  if s.skip and math.random() < 0.4 then
    s.step = (s.step % 64) + 1
    return
  end

  local pat      = PATTERNS[s.pat_idx]
  local offsets  = CHORDS[s.chord]
  local base_deg = pat[((s.step - 1) % #pat) + 1]
  local dur      = step_sec() * s.gate

  local vel = s.velocity
  if s.vel_ramp ~= 0 then
    s.vel_ramp_step = s.vel_ramp_step + 1
    local t = clamp(s.vel_ramp_step / 16.0, 0, 1)
    vel = s.vel_ramp == 1
      and (0.3 + t * 0.7)
      or  (1.0 - t * 0.7)
    vel = clamp(vel, 0.1, 1.0)
  end

  if s.minimal then
    if s.step % 2 == 1 then
      play_note(scale_note(base_deg), vel, dur)
    end
  else
    local notes = {}
    for _, off in ipairs(offsets) do
      table.insert(notes, scale_note(base_deg + off))
    end
    if s.cascade and #notes > 1 then
      for i, n in ipairs(notes) do
        local delay = (i - 1) * dur * 0.15
        clock.run(function()
          clock.sleep(delay)
          play_note(n, vel, dur)
        end)
      end
    else
      for _, n in ipairs(notes) do
        play_note(n, vel, dur)
      end
      if s.chorus then
        clock.run(function()
          clock.sleep(0.012)
          play_note(notes[1], vel * 0.5, dur)
        end)
      end
    end
  end

  s.step = (s.step % 64) + 1
end

local function start_seq()
  if seq_id then clock.cancel(seq_id) end
  s.playing = true
  seq_id = clock.run(function()
    while true do
      advance()
      clock.sleep(step_sec())
    end
  end)
end

local function stop_seq()
  s.playing = false
  if seq_id then
    clock.cancel(seq_id)
    seq_id = nil
  end
  engine.hz(0)
end

--------------------------------------------------------------------------------
-- HI-RES HELMET RENDERER
-- 1px per pixel, 16-level brightness, drawn analytically each frame.
-- Helmet coordinate space: centre = (0,0), spans ~±22x, -28..+14y
--------------------------------------------------------------------------------

-- Returns brightness 0-15 for pixel (px,py) relative to helmet centre,
-- or -1 if the pixel is outside the helmet silhouette.
-- is_thomas: true = gold visor (Thomas), false = silver (Guy-Man)
local function helmet_pixel(px, py, is_thomas, beat_pulse)
  -- ── silhouette ──────────────────────────────────────────────────────────
  local in_dome = (px*px)/(22*22) + ((py+10)*(py+10))/(24*24) < 1.0
  local in_face = math.abs(px) <= 18 and py >= -8 and py <= 14
  local in_neck = math.abs(px) <= 10 and py >= 10 and py <= 18

  if not (in_dome or in_face or in_neck) then return -1 end

  -- ── ear discs ────────────────────────────────────────────────────────────
  local ear_cx = is_thomas and -22 or 22     -- mirror side per helmet
  local ear_dist = math.sqrt((px - ear_cx)^2 + (py + 2)^2)
  local ear_dist2 = math.sqrt((px + ear_cx)^2 + (py + 2)^2)
  if ear_dist < 5 or ear_dist2 < 5 then
    local d = math.min(ear_dist, ear_dist2)
    return d < 3 and 9 or 6
  end

  -- ── visor band ───────────────────────────────────────────────────────────
  local vy0 = is_thomas and -4 or -3
  local vy1 = is_thomas and  6 or  5
  local vx  = is_thomas and 16 or 15

  if py >= vy0 and py <= vy1 and math.abs(px) <= vx then
    local cx = px / vx
    local cy = (py - (vy0 + vy1) * 0.5) / ((vy1 - vy0) * 0.5)
    local radial = math.sqrt(cx*cx + cy*cy * 0.6)
    local base   = is_thomas and 15 or 13
    local glow   = clamp(math.floor(base - radial * 9 + beat_pulse * 3), 3, 15)
    return glow
  end

  -- ── visor surround (dark trim) ────────────────────────────────────────────
  local near_visor = math.abs(py - (vy0 + vy1) * 0.5) < (vy1 - vy0) * 0.5 + 4
                     and math.abs(px) <= vx + 1
  if near_visor then return 1 end

  -- ── dome shading (top-left light source) ─────────────────────────────────
  if in_dome and not in_face then
    local nx   = px / 22.0
    local ny   = (py + 10) / 24.0
    local diff = clamp(1.0 - (nx * 0.4 + ny * 0.5 + 0.3), 0, 1)
    -- edge darkening
    local edge = (px*px)/(20*20) + ((py+10)*(py+10))/(22*22)
    if edge > 1.0 then
      return clamp(math.floor(diff * 5 + 1), 1, 6)
    end
    return clamp(math.floor(diff * 9 + 3), 3, 12)
  end

  -- ── face plate ───────────────────────────────────────────────────────────
  if in_face then
    local edge_x = math.abs(px) >= 16
    local edge_y = py >= 12
    if edge_x or edge_y then return 2 end
    local diff = clamp(1.0 - math.abs(px) / 20.0 * 0.5 - py / 20.0 * 0.3, 0, 1)
    return clamp(math.floor(diff * 6 + 2), 2, 8)
  end

  -- neck
  return 3
end

-- Draw one helmet onto the Norns screen.
-- cx, cy: top-left corner of the 48×36 drawing region
-- ox, oy: sub-pixel animation offset (floored to int inside)
-- is_thomas, beat_pulse: passed through to helmet_pixel
local function draw_helmet(cx, cy, ox, oy, is_thomas, beat_pulse)
  local iox = math.floor(ox)
  local ioy = math.floor(oy)
  -- helmet centre within the 48×36 region
  local hcx = 24
  local hcy = 20

  for py = -28, 18 do
    for px = -22, 22 do
      local lv = helmet_pixel(px, py, is_thomas, beat_pulse)
      if lv >= 0 then
        local sx = cx + hcx + px + iox
        local sy = cy + hcy + py + ioy
        if sx >= 0 and sx < 128 and sy >= 0 and sy < 64 then
          -- scanline dimming: every other row slightly dimmer
          local sl = sy % 2 == 0 and math.max(0, lv - 2) or lv
          if sl > 0 then
            screen.level(sl)
            screen.rect(sx, sy, 1, 1)
            screen.fill()
          end
        end
      end
    end
  end
end

--------------------------------------------------------------------------------
-- SCREEN
--------------------------------------------------------------------------------

local anim_t    = 0.0
local flash_t   = 0.0
local flash_lbl = ""
local arp_step_vis = 0.0   -- visual step counter for dot strip

local FLASH_LABELS = {
  "SCALE","CHORD","PAT","OCT","BEND","BPM",
  "STUT","FX","GATE","VEL","ROOT","FILT","PATCH","COMBO","CHAOS","RESET",
}

function redraw()
  screen.clear()

  -- beat pulse (0..1) synced to BPM for visor glow
  local beat_pulse = s.playing
    and (math.sin(anim_t * (s.bpm / 60.0) * math.pi) * 0.5 + 0.5)
    or  0.5

  -- ── helmets ──────────────────────────────────────────────────────────────
  -- Thomas: left region x=2, Guy-Man: right region x=76
  -- Independent sway/nod at different frequencies
  local ox1 = math.sin(anim_t * 0.7) * 2.5
  local oy1 = math.cos(anim_t * 0.5) * 1.5
  local ox2 = math.sin(anim_t * 0.9 + math.pi) * 2.0
  local oy2 = math.cos(anim_t * 0.6 + math.pi) * 1.8

  draw_helmet(2,  10, ox1, oy1, true,  beat_pulse)
  draw_helmet(76, 10, ox2, oy2, false, beat_pulse)

  -- ── HUD ──────────────────────────────────────────────────────────────────
  screen.font_face(1)
  screen.font_size(8)

  -- scale name top-left
  screen.level(13)
  screen.move(1, 8)
  screen.text(string.upper(s.scale))

  -- BPM top-right
  screen.level(7)
  screen.move(88, 8)
  screen.text(s.bpm .. "BPM")

  -- play dot (pulsing) / PAUSED label
  if s.playing then
    local pulse_lv = clamp(math.floor((math.sin(anim_t * (s.bpm / 60.0) * 2 * math.pi) + 1) * 4) + 7, 7, 15)
    screen.level(pulse_lv)
    screen.circle(64, 4, 2)
    screen.fill()
  else
    screen.level(4)
    screen.move(52, 8)
    screen.text("PAUSED")
  end

  -- 16-step dot strip (top centre, tracks arp position)
  if s.playing then
    for i = 0, 15 do
      local active = math.floor(arp_step_vis) % 16 == i
      screen.level(active and 15 or 2)
      screen.rect(40 + i * 3, 1, 2, 2)
      screen.fill()
    end
  end

  -- active fx strip (bottom left)
  local fx_str = ""
  if s.chorus  then fx_str = fx_str .. "CHO "  end
  if s.minimal then fx_str = fx_str .. "MIN "  end
  if s.distort then fx_str = fx_str .. "DST "  end
  if s.stutter then fx_str = fx_str .. "STT/" .. s.stutter_div .. " " end
  if s.glide   then fx_str = fx_str .. "GLD "  end
  if s.cascade then fx_str = fx_str .. "CAS "  end
  if s.skip    then fx_str = fx_str .. "SKP "  end

  screen.level(5)
  screen.font_size(8)
  screen.move(1, 63)
  screen.text(fx_str)

  -- flash label (bottom centre)
  if flash_t > 0 then
    screen.level(clamp(math.floor(flash_t * 14), 1, 15))
    screen.font_size(8)
    screen.move(64, 63)
    screen.text_center(flash_lbl)
    flash_t = math.max(0, flash_t - 0.08)
  end

  screen.update()
end

--------------------------------------------------------------------------------
-- GRID
--------------------------------------------------------------------------------

local g = grid.connect()

-- Roulette action table: ACTIONS[row][col] = fn | nil
local ACTIONS = {}

local ACTION_POOL = {
  function() s.scale = "acid"       end,
  function() s.scale = "phrygian"   end,
  function() s.scale = "dorian"     end,
  function() s.scale = "pentatonic" end,
  function() s.scale = "wholetone"  end,
  function() s.chord = "root"   end,
  function() s.chord = "power"  end,
  function() s.chord = "minor"  end,
  function() s.chord = "major"  end,
  function() s.chord = "dim"    end,
  function() s.chord = "sus4"   end,
  function() s.chord = "octave" end,
  function() s.pat_idx = 1 end,
  function() s.pat_idx = 2 end,
  function() s.pat_idx = 3 end,
  function() s.pat_idx = 4 end,
  function() s.pat_idx = 5 end,
  function() s.pat_idx = 6 end,
  function() s.pat_idx = 7 end,
  function() s.pat_idx = 8 end,
  function() s.pat_idx = math.random(#PATTERNS) end,
  function() s.octave_shift = clamp(s.octave_shift + 1, -2, 2) end,
  function() s.octave_shift = clamp(s.octave_shift - 1, -2, 2) end,
  function() s.octave_shift = 0 end,
  function() s.pitch_bend = clamp(s.pitch_bend + 1, -7, 7) end,
  function() s.pitch_bend = clamp(s.pitch_bend - 1, -7, 7) end,
  function() s.pitch_bend = clamp(s.pitch_bend + 2, -7, 7) end,
  function() s.pitch_bend = clamp(s.pitch_bend - 2, -7, 7) end,
  function() s.pitch_bend = clamp(s.pitch_bend + 5, -7, 7) end,
  function() s.pitch_bend = clamp(s.pitch_bend - 5, -7, 7) end,
  function() s.pitch_bend = 0 end,
  function() s.bpm = clamp(s.bpm + 10, 60, 200); if s.playing then start_seq() end end,
  function() s.bpm = clamp(s.bpm - 10, 60, 200); if s.playing then start_seq() end end,
  function() s.bpm = clamp(s.bpm + 20, 60, 200); if s.playing then start_seq() end end,
  function() s.bpm = clamp(s.bpm - 20, 60, 200); if s.playing then start_seq() end end,
  function() s.bpm = 120; if s.playing then start_seq() end end,
  function() s.bpm = 128; if s.playing then start_seq() end end,
  function() s.bpm = 140; if s.playing then start_seq() end end,
  function() s.bpm = 160; if s.playing then start_seq() end end,
  function() s.bpm = 174; if s.playing then start_seq() end end,
  function() s.bpm = math.random(100,180); if s.playing then start_seq() end end,
  function() s.stutter = true;  s.stutter_div = 2 end,
  function() s.stutter = true;  s.stutter_div = 4 end,
  function() s.stutter = true;  s.stutter_div = 8 end,
  function() s.stutter = false; s.stutter_div = 1 end,
  function() s.chorus  = not s.chorus  end,
  function() s.minimal = not s.minimal end,
  function() s.distort = not s.distort end,
  function() s.glide   = not s.glide   end,
  function() s.skip    = not s.skip    end,
  function() s.cascade = not s.cascade end,
  function() s.gate = 0.1 end,
  function() s.gate = 0.5 end,
  function() s.gate = 0.8 end,
  function() s.gate = 1.0 end,
  function() s.velocity = 0.3 end,
  function() s.velocity = 0.6 end,
  function() s.velocity = 1.0 end,
  function() s.vel_ramp = 1;  s.vel_ramp_step = 0 end,
  function() s.vel_ramp = -1; s.vel_ramp_step = 0 end,
  function() s.vel_ramp = 0 end,
  function() s.swing = 0  end,
  function() s.swing = 25 end,
  function() s.swing = 50 end,
  function() s.root_midi = clamp(s.root_midi + 1,  24, 60) end,
  function() s.root_midi = clamp(s.root_midi - 1,  24, 60) end,
  function() s.root_midi = clamp(s.root_midi + 7,  24, 60) end,
  function() s.root_midi = clamp(s.root_midi - 7,  24, 60) end,
  function() s.root_midi = 36 end,
  function() s.cutoff = 400;  engine.cutoff(s.cutoff) end,
  function() s.cutoff = 1200; engine.cutoff(s.cutoff) end,
  function() s.cutoff = 3000; engine.cutoff(s.cutoff) end,
  function() s.cutoff = 8000; engine.cutoff(s.cutoff) end,
  randomise_patch,
  -- combos
  function() s.scale = "acid"; s.stutter = true; s.stutter_div = 4 end,
  function() s.octave_shift = clamp(s.octave_shift-1,-2,2); s.chord = "power" end,
  function() s.chorus = true; s.velocity = 1.0 end,
  function() s.scale = "phrygian"; s.glide = true end,
  function() s.distort = true; s.bpm = clamp(math.floor(s.bpm*1.5),60,200); if s.playing then start_seq() end end,
  function() s.minimal = true; s.gate = 0.1 end,
  function() s.stutter = true; s.stutter_div = 4; s.pitch_bend = clamp(s.pitch_bend+2,-7,7) end,
  function() s.pat_idx = 5; s.chorus = true end,
  function() s.cascade = true; s.swing = 30 end,
  function() s.chord = "dim"; s.octave_shift = clamp(s.octave_shift-1,-2,2) end,
  function() s.minimal = true; s.pat_idx = 1 end,
  function()
    s.scale   = SCALE_NAMES[math.random(#SCALE_NAMES)]
    s.chord   = CHORD_NAMES[math.random(#CHORD_NAMES)]
    s.pat_idx = math.random(#PATTERNS)
    s.bpm     = math.random(100,170)
    s.octave_shift = math.random(-1,1)
    s.pitch_bend   = math.random(-3,3)
    s.stutter = math.random() > 0.6
    s.stutter_div  = rnd({2,4,8})
    s.chorus  = math.random() > 0.5
    s.distort = math.random() > 0.6
    randomise_patch()
    if s.playing then start_seq() end
  end,
  function() s.scale = "dorian"; s.chord = "power"; s.swing = 25 end,
  function() s.cutoff = 8000; engine.cutoff(s.cutoff); s.cascade = true end,
  function() s.octave_shift = clamp(s.octave_shift-1,-2,2); s.stutter = true; s.stutter_div = 4 end,
  function() s.scale = "wholetone"; s.chorus = true; s.bpm = clamp(s.bpm+20,60,200); if s.playing then start_seq() end end,
  function() s.scale = "acid"; s.pat_idx = 5; s.stutter = true; s.stutter_div = 4 end,
  function() s.skip = true; s.scale = "phrygian" end,
  reset_fx,
  function() s.glide = true; s.distort = true end,
  function() s.scale = "pentatonic"; s.bpm = clamp(math.floor(s.bpm*1.5),60,200); if s.playing then start_seq() end end,
  function() s.chord = "sus4"; s.cascade = true end,
  function() s.stutter = true; s.stutter_div = 8; s.skip = true end,
  function() s.octave_shift = clamp(s.octave_shift+1,-2,2); s.chorus = true end,
  function() s.minimal = true; s.glide = true; s.scale = "dorian" end,
  function() s.vel_ramp = 1; s.scale = "acid"; s.vel_ramp_step = 0 end,
  function() s.minimal = true; s.pat_idx = 1; s.distort = true end,
  function() randomise_patch(); s.bpm = math.random(100,170); if s.playing then start_seq() end end,
}

local function build_roulette()
  -- Fisher-Yates shuffle
  local pool = {}
  for _, a in ipairs(ACTION_POOL) do table.insert(pool, a) end
  for i = #pool, 2, -1 do
    local j = math.random(i)
    pool[i], pool[j] = pool[j], pool[i]
  end
  -- tile to 126 slots
  local tiled = {}
  while #tiled < 126 do
    for _, a in ipairs(pool) do
      table.insert(tiled, a)
      if #tiled >= 126 then break end
    end
  end
  -- assign to grid, skipping [col=1,row=1] and [col=2,row=1]
  local idx = 1
  for row = 1, 8 do
    ACTIONS[row] = {}
    for col = 1, 16 do
      if row == 1 and (col == 1 or col == 2) then
        ACTIONS[row][col] = nil
      else
        ACTIONS[row][col] = tiled[idx]
        idx = idx + 1
      end
    end
  end
end

-- pulsing roulette LEDs
local pulse_cells = {}
local function refresh_pulse_cells()
  pulse_cells = {}
  if s.playing then
    for _ = 1, 6 do
      local row = math.random(1, 8)
      local col = math.random(1, 16)
      if not (row == 1 and (col == 1 or col == 2)) then
        table.insert(pulse_cells, {row, col})
      end
    end
  end
end

local function grid_draw()
  if g == nil then return end
  g:all(0)
  g:led(1, 1, s.playing and 15 or 5)
  g:led(2, 1, s.playing and 4  or 12)
  for row = 1, 8 do
    for col = 1, 16 do
      if not (row == 1 and (col == 1 or col == 2)) then
        g:led(col, row, 2)
      end
    end
  end
  local pulse_lv = clamp(math.floor((math.sin(anim_t * 4) + 1) * 3) + 3, 3, 9)
  for _, pc in ipairs(pulse_cells) do
    g:led(pc[2], pc[1], pulse_lv)
  end
  g:refresh()
end

local function grid_key(x, y, z)
  if z == 0 then return end

  if y == 1 and x == 1 then
    start_seq()
    return
  end
  if y == 1 and x == 2 then
    stop_seq()
    return
  end

  local action = ACTIONS[y] and ACTIONS[y][x]
  if action then
    action()
    local slot = (y - 1) * 16 + x
    flash_lbl = FLASH_LABELS[(slot % #FLASH_LABELS) + 1]
    flash_t   = 1.0
  end
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------

function init()
  math.randomseed(os.time())

  apply_patch()
  engine.gain(0.8)

  build_roulette()

  if g ~= nil then
    g.key = grid_key
  end

  -- main loop: animation + screen + grid at ~12 fps
  clock.run(function()
    while true do
      local dt = 1.0 / 12.0
      anim_t = anim_t + dt
      if s.playing then
        arp_step_vis = arp_step_vis + dt * (s.bpm / 60.0) * 4.0
      end
      refresh_pulse_cells()
      redraw()
      grid_draw()
      clock.sleep(dt)
    end
  end)

  start_seq()
end

function cleanup()
  stop_seq()
end

--------------------------------------------------------------------------------
-- NORNS ENCODERS
--------------------------------------------------------------------------------

function enc(n, d)
  if n == 1 then
    s.bpm = clamp(s.bpm + d, 60, 200)
    if s.playing then start_seq() end
  elseif n == 2 then
    s.root_midi = clamp(s.root_midi + d, 24, 60)
  elseif n == 3 then
    s.cutoff = clamp(s.cutoff + d * 100, 100, 8000)
    engine.cutoff(s.cutoff)
  end
end

--------------------------------------------------------------------------------
-- NORNS BUTTONS
--------------------------------------------------------------------------------

function key(n, z)
  if z == 0 then return end
  if n == 2 then
    if s.playing then stop_seq() else start_seq() end
  elseif n == 3 then
    randomise_patch()
    flash_lbl = "PATCH"
    flash_t   = 1.0
  end
end
