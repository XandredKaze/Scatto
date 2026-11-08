--[[
  WaveOBS per OBS: avvia waveobs.exe (il ponte con Elgato Wave Link) quando si apre OBS.
  WaveOBS si chiude da solo quando OBS si chiude.

  Installazione: OBS -> Strumenti -> Script -> "+" -> scegli questo file.
  Metti waveobs.lua, waveobs.exe e config.json nella stessa cartella.
]]

local obs = obslua
local ffi = require("ffi")

local IS_WINDOWS = ffi.os == "Windows"
local settings_ref = nil

local function default_exe()
  return script_path() .. (IS_WINDOWS and "waveobs.exe" or "waveobs")
end

local function dir_of(path)
  return path:match("^(.*)[/\\]") or "."
end

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

----------------------------------------------------------------------
-- Avvio processi (Windows: ShellExecuteW, nessuna finestra visibile)
----------------------------------------------------------------------
local shell32, kernel32
if IS_WINDOWS then
  ffi.cdef([[
    typedef unsigned short WCHAR;
    int MultiByteToWideChar(unsigned int cp, unsigned long flags, const char* src, int srclen, WCHAR* dst, int dstlen);
    void* ShellExecuteW(void* hwnd, const WCHAR* op, const WCHAR* file, const WCHAR* params, const WCHAR* dir, int show);
  ]])
  shell32 = ffi.load("shell32")
  kernel32 = ffi.load("kernel32")
end

local function wide(s)
  if s == nil then return nil end
  local n = kernel32.MultiByteToWideChar(65001, 0, s, -1, nil, 0)
  local buf = ffi.new("WCHAR[?]", n)
  kernel32.MultiByteToWideChar(65001, 0, s, -1, buf, n)
  return buf
end

-- show: 0 = nascosto, 1 = normale
local function shell_open(file, params, dir, show)
  if IS_WINDOWS then
    local r = shell32.ShellExecuteW(nil, wide("open"), wide(file), wide(params), wide(dir), show)
    return tonumber(ffi.cast("intptr_t", r)) > 32
  else
    local cmd = string.format("cd %q && %q %s >/dev/null 2>&1 &", dir or ".", file, params or "")
    local r = os.execute(cmd)
    return r == 0 or r == true
  end
end

local function open_file(path)
  if IS_WINDOWS then
    return shell_open(path, nil, dir_of(path), 1)
  end
  local opener = ffi.os == "OSX" and "open" or "xdg-open"
  return os.execute(string.format("%s %q &", opener, path))
end

----------------------------------------------------------------------
-- Azioni
----------------------------------------------------------------------
local function exe_path()
  local p = settings_ref and obs.obs_data_get_string(settings_ref, "exe_path") or ""
  if p == nil or p == "" then p = default_exe() end
  return p
end

local function start_waveobs()
  local exe = exe_path()
  if not file_exists(exe) then
    obs.script_log(obs.LOG_WARNING, "[WaveOBS] eseguibile non trovato: " .. exe)
    return false
  end
  local dir = dir_of(exe)
  if not file_exists(dir .. "/config.json") then
    obs.script_log(obs.LOG_WARNING, "[WaveOBS] manca config.json in " .. dir .. " (premi 'Modifica configurazione')")
  end
  -- Se WaveOBS è già in esecuzione, la nuova istanza prende il suo posto.
  local ok = shell_open(exe, "run --with-obs", dir, 0)
  if ok then
    obs.script_log(obs.LOG_INFO, "[WaveOBS] avviato: " .. exe)
  else
    obs.script_log(obs.LOG_WARNING, "[WaveOBS] impossibile avviare " .. exe)
  end
  return ok
end

local function edit_config()
  local dir = dir_of(exe_path())
  local cfg = dir .. "/config.json"
  if not file_exists(cfg) then
    local src = io.open(dir .. "/config.example.json", "rb")
    if src then
      local data = src:read("*a")
      src:close()
      local dst = io.open(cfg, "wb")
      if dst then dst:write(data) dst:close() end
    end
  end
  open_file(cfg)
end

----------------------------------------------------------------------
-- Interfaccia script OBS
----------------------------------------------------------------------
function script_description()
  return [[<h3>WaveOBS — Wave Link ⇄ OBS</h3>
<p>Avvia WaveOBS quando apri OBS. WaveOBS si chiude da solo quando chiudi OBS.</p>
<p>Dopo aver modificato <code>config.json</code> premi <b>Riavvia WaveOBS</b>.</p>]]
end

function script_properties()
  local props = obs.obs_properties_create()
  obs.obs_properties_add_path(props, "exe_path", "Eseguibile WaveOBS", obs.OBS_PATH_FILE,
    IS_WINDOWS and "waveobs.exe (*.exe)" or "waveobs (*)", script_path())
  obs.obs_properties_add_bool(props, "autostart", "Avvia WaveOBS insieme a OBS")
  obs.obs_properties_add_button(props, "restart", "Riavvia WaveOBS", function() start_waveobs() return false end)
  obs.obs_properties_add_button(props, "edit", "Modifica configurazione", function() edit_config() return false end)
  obs.obs_properties_add_button(props, "log", "Apri log", function()
    open_file(dir_of(exe_path()) .. "/waveobs.log")
    return false
  end)
  return props
end

function script_defaults(settings)
  obs.obs_data_set_default_string(settings, "exe_path", default_exe())
  obs.obs_data_set_default_bool(settings, "autostart", true)
end

function script_update(settings)
  settings_ref = settings
end

function script_load(settings)
  settings_ref = settings
  if obs.obs_data_get_bool(settings, "autostart") then
    start_waveobs()
  end
end
