--
-- Author: soul
-- Date: 2020/8/20 13:42:11
-- Brief: 
--

-- @alias SpriteAtlasManager
local M = {}
declare("SpriteAtlasManager", M)

local SpriteAtlasManagerDefine = requireLua("SpriteAtlasManagerDefine")

local TP_SPRITE_ATLAS_PATH_FORMAT = SpriteAtlasManagerDefine.TP_SPRITE_ATLAS_PATH_FORMAT
local PRELOAD_TP_ATLAS_ARRAY      = SpriteAtlasManagerDefine.PRELOAD_TP_ATLAS_ARRAY
local TPSprite                    = SpriteAtlasManagerDefine.TPSprite
local ATLAS_KEY_MAP               = SpriteAtlasManagerDefine.ATLAS_KEY_MAP


local TPSpriteMap = {}
M._isTPAtlasPreload = false


function M.preloadTPAltas()
    if M._isTPAtlasPreload then
        return
    end
    M._isTPAtlasPreload = true

    TPSpriteMap = {}

    for i = 1, #PRELOAD_TP_ATLAS_ARRAY do
        M.loadTPSprite(PRELOAD_TP_ATLAS_ARRAY[i])
    end

    log.dump(TPSpriteMap, "TPSpriteMap TPSpriteMap")
end

function M.loadTPSprite(atlasName)
    local sprites = RES:LoadTPSprite(atlasName, string.format(TP_SPRITE_ATLAS_PATH_FORMAT, TPSprite[atlasName]))

    TPSpriteMap[atlasName] = {}

    for i = 0, sprites.Length - 1 do
        local sprite = sprites[i]
        TPSpriteMap[atlasName][sprite.name] = sprite
    end
end

--// key: arena2/arena2_duanwei_101
function M.getTPSprite(key)
    local keys = string.split(key, "/")
    local atlasName = ATLAS_KEY_MAP[keys[1]]
    local spriteName = keys[2]

    if TPSpriteMap[atlasName] == nil then
        M.loadTPSprite(atlasName)
    end

    local sprite = TPSpriteMap[atlasName][spriteName]
    if CNull(sprite) then
        M.loadTPSprite(atlasName)
        sprite = TPSpriteMap[atlasName][spriteName]
    end

    return sprite
end


return M