-- Target channels and main configuration:
SOUNDS_CONFIG = {
    soundChannel = SoundChannels.Music,
    effectsOpcode = 91 --custom code to hear out specific actions from server side.
    checkInterval = 50, --ms
    fadeOutTime = 1, --sec
    fadeInTime = 1, --sec
    folder = '/data/sounds/',
    noSound = 'No sound file for this area.',
}

-- Define matrix areas using x,z,y.
SOUNDS = {
	-- Example
			-- Music: City   
			{fromPos = {x=928, y=1005, z=7}, toPos = {x=1090, y=1090, z=7}, priority = 1, sound="/music/city.ogg"},	
			-- Effect: Fountain
			{fromPos = {x=1011, y=1036, z=7}, toPos = {x=1023, y=1047, z=7}, priority = 1, sound="/ambient/fountain.ogg", soundType="ambient"},	
} ----------

-- Sound
local rcSoundChannel
local rcSoundAmbientChannel
local rcSoundEffectChannel
local showPosEvent
local playingSound = {}
local playChannels = {}

-- CSS and UI Design
soundWindow = nil
soundButton = nil

-- UI Window appear
function toggle()
  if soundButton:isOn() then
    soundWindow:close()
    soundButton:setOn(false)
  else
    soundWindow:open()
    soundButton:setOn(true)
  end
end

function onMiniWindowClose()
  soundButton:setOn(false)
end

-- main
function init()
    for i = 1, #SOUNDS do
        SOUNDS[i].sound = SOUNDS_CONFIG.folder .. SOUNDS[i].sound
    end
    
    connect(g_game, { onGameStart = onGameStart,
                    onGameEnd = onGameEnd })

	ProtocolGame.registerExtendedOpcode(SOUNDS_CONFIG.effectsOpcode, function(protocol, opcode, buffer) rcSoundEffectChannel:enqueue(SOUNDS_CONFIG.folder .. "effects/" .. buffer .. ".ogg", 0) scheduleEvent(function() rcSoundEffectChannel:stop(SOUNDS_CONFIG.fadeOutTime) end, 1000) end)

    rcSoundChannel = g_sounds.getChannel(SOUNDS_CONFIG.soundChannel)
    rcSoundAmbientChannel = g_sounds.getChannel(SoundChannels.Ambient)
    rcSoundEffectChannel = g_sounds.getChannel(SoundChannels.Effect)
    -- rcSoundChannel:setGain(value/COUNDS_CONFIG.volume) Testing Vol.


    soundButton = modules.client_topmenu.addRightGameToggleButton('soundButton', tr('Sound Info') .. '', '/images/audio', toggle)
    soundButton:setOn(true)
    
    soundWindow = g_ui.loadUI('rcsound', modules.game_interface.getRightPanel())
    soundWindow:disableResize()
    soundWindow:setup()
    
    if(g_game.isOnline()) then
        onGameStart()
    end
end

function terminate()
    disconnect(g_game, { onGameStart = onGameStart,
                       onGameEnd = onGameEnd })
    ProtocolGame.unregisterExtendedOpcode(SOUNDS_CONFIG.effectsOpcode)
    onGameEnd()
    soundWindow:destroy()
    soundButton:destroy()
end

function onGameStart()
    stopSounds(true, true)
    toggleSoundEvent = addEvent(toggleSound, SOUNDS_CONFIG.checkInterval)
end

function onGameEnd()
    stopSounds(true, true)
    removeEvent(toggleSoundEvent)
end

function isInPos(pos, fromPos, toPos)
    return
        pos.x>=fromPos.x and
        pos.y>=fromPos.y and
        pos.z>=fromPos.z and
        pos.x<=toPos.x and
        pos.y<=toPos.y and
        pos.z<=toPos.z
end

function toggleSound()
    local player = g_game.getLocalPlayer()
    if not player then return end
    
    local pos = player:getPosition()
    local toPlay = {}


    for i = 1, #SOUNDS do
        if(isInPos(pos, SOUNDS[i].fromPos, SOUNDS[i].toPos)) then
            local soundType = SOUNDS[i].soundType and SOUNDS[i].soundType or "music"
            if(toPlay and toPlay[soundType]) then
                toPlay[soundType].priority = toPlay[soundType].priority or 0
                if((toPlay.sound~=SOUNDS[i].sound) and (SOUNDS[i].priority>toPlay.priority)) then
                    toPlay[toPlay.soundType] = SOUNDS[i]

                    if (toPlay[soundType].soundType and toPlay[soundType].soundType == "ambient" and not table.contains(playChannels, "ambient")) then
                        table.insert(playChannels, "ambient")
                    elseif (not table.contains(playChannels, "music")) then
                        table.insert(playChannels, "music")
                    end
                end
            else
                toPlay[soundType] = SOUNDS[i]

                if (toPlay[soundType].soundType and toPlay[soundType].soundType == "ambient" and not table.contains(playChannels, "ambient")) then
                    table.insert(playChannels, "ambient")
                elseif (not table.contains(playChannels, "music")) then
                    table.insert(playChannels, "music")
                end
            end
        end
    end

    playingSound["music"] = playingSound["music"] or {sound='', priority=0}
    playingSound["ambient"] = playingSound["ambient"] or {sound='', priority=0}

    if(toPlay["music"] ~= nil or toPlay["ambient"] ~= nil) then
        if ((not playingSound["music"] and toPlay["music"]) or (toPlay["music"] and playingSound["music"].sound ~= toPlay["music"].sound)) then
            g_logger.info("RC Sounds: New sound area detected:")
            g_logger.info("  Position: {x=" .. pos.x .. ", y=" .. pos.y .. ", z=" .. pos.z .. "}")
            g_logger.info("  Music: " .. toPlay["music"].sound)
            stopMusicSounds()
            playingSound["music"] = toPlay["music"]
            playSingleSound(toPlay["music"])
        end

        if (playingSound["music"] and not toPlay["music"]) then
            stopMusicSounds()
        end

        if ((not playingSound["ambient"] and toPlay["ambient"]) or (toPlay["ambient"] and playingSound["ambient"].sound ~= toPlay["ambient"].sound)) then
            g_logger.info("RC Sounds: New sound area detected:")
            g_logger.info("  Position: {x=" .. pos.x .. ", y=" .. pos.y .. ", z=" .. pos.z .. "}")
            g_logger.info("  Ambient: " .. toPlay["ambient"].sound)
            stopAmbientSounds()
            playingSound["ambient"] = toPlay["ambient"]
            playSingleSound(toPlay["ambient"])
        end
        
        if (playingSound["ambient"] and not toPlay["ambient"]) then
            stopAmbientSounds()
        end
    elseif(toPlay["ambient"] == nil and toPlay["music"] == nil) and (playingSound["music"].sound~='' or playingSound["ambient"].sound~='') then
        g_logger.info("RC Sounds: New sound area detected:")
        g_logger.info("  Left music area.")
        stopSounds()
    end
    toggleSoundEvent = scheduleEvent(toggleSound, SOUNDS_CONFIG.checkInterval)
end

-- Play functions based on vol. and fade in/out settings 
function playSound(play)
    if (play["ambient"]) then
        rcSoundAmbientChannel:enqueue(play["ambient"].sound, SOUNDS_CONFIG.fadeInTime)
        setLabel(clearName(play["ambient"].sound))
    end
    if (play["music"]) then
        rcSoundChannel:enqueue(play["music"].sound, SOUNDS_CONFIG.fadeInTime)
        setLabel(clearName(play["music"].sound))
    end
end

-- Ambient
function playSingleSound(play)
    local soundChannel = rcSoundChannel
    if (play.soundType and play.soundType == "ambient") then
        soundChannel = rcSoundAmbientChannel
    end
    soundChannel:enqueue(play.sound, SOUNDS_CONFIG.fadeInTime)
    setLabel(clearName(play.sound))
end

-- Clear Text when zone is over
function clearName(soundName)
    local explode = string.explode(soundName, "/")
    soundName = explode[#explode]
    explode = string.explode(soundName, ".ogg")
    soundName = ''
    for i = 1, #explode-1 do
        soundName = soundName .. explode[i]
    end
    return soundName
end

-- Stop SFX channel sounds
function stopSounds()
    setLabel(SOUNDS_CONFIG.noSound)

    stopAmbientSounds()
    stopMusicSounds()
end

-- Stop Music sounds
function stopMusicSounds()
    rcSoundChannel:stop(SOUNDS_CONFIG.fadeOutTime)
    playingSound["music"] = nil
    table.removevalue(playChannels, "music")
end

-- Stop Ambient sounds.
function stopAmbientSounds()
    rcSoundAmbientChannel:stop(SOUNDS_CONFIG.fadeOutTime)
    playingSound["ambient"] = nil
    table.removevalue(playChannels, "ambient")
end

-- Update UI window text
function setLabel(str)
    soundWindow:recursiveGetChildById('currentSound'):getChildById('value'):setText(str)
end
