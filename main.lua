----------------------------
-- TILE SETUP & RULES
----------------------------

-- Define tile types
local TILES = {
    WATER = 1,
    SAND  = 2,
    GRASS = 3,
    FOREST = 4,
    LAVA = 5,
    MOUNTAIN = 6,
    ROCK = 7,
}

-- Define colors corresponding to each tile type
local COLORS = {
    [TILES.WATER]  = {0.2, 0.4, 0.9, 1.0},  -- Blue
    [TILES.SAND]   = {0.9, 0.8, 0.5, 1.0},  -- Yellow
    [TILES.GRASS]  = {0.3, 0.7, 0.2, 1.0},  -- Green
    [TILES.FOREST] = {0.1, 0.4, 0.1, 1.0},  -- Dark Green
    [TILES.LAVA]     = {1.0, 0.3, 0.0, 1.0},    -- orange-red for volcanic areas
    [TILES.MOUNTAIN] = {0.6, 0.6, 0.6, 1.0},    -- gray for elevated, rugged terrain
    [TILES.ROCK]     = {0.4, 0.4, 0.4, 1.0},    -- uniform gray for rocky.

    UNCOLLAPSED    = {1, 1, 1, 1},  -- White for non-collapsed cells
}

-- Define adjacency rules.
local rules = {}

local function addRule(t1, t2, dir)
    rules[t1] = rules[t1] or {}
    rules[t1][t2] = rules[t1][t2] or {}
    rules[t1][t2][dir] = true
end

local function addMutualRule(t1, t2, dir1, dir2)
    addRule(t1, t2, dir1)
    addRule(t2, t1, dir2)
end

-- Define simple transition rules for our tiles.

-- Water next to Water/Sand
addMutualRule(TILES.WATER, TILES.WATER, "up", "down")
addMutualRule(TILES.WATER, TILES.WATER, "right", "left")
addMutualRule(TILES.WATER, TILES.SAND, "up", "down")
addMutualRule(TILES.WATER, TILES.SAND, "right", "left")

-- Sand next to Water/Sand/Grass
addMutualRule(TILES.SAND, TILES.SAND, "up", "down")
addMutualRule(TILES.SAND, TILES.SAND, "right", "left")
addMutualRule(TILES.SAND, TILES.GRASS, "up", "down")
addMutualRule(TILES.SAND, TILES.GRASS, "right", "left")

-- Grass next to Sand/Grass/Forest
addMutualRule(TILES.GRASS, TILES.GRASS, "up", "down")
addMutualRule(TILES.GRASS, TILES.GRASS, "right", "left")
addMutualRule(TILES.GRASS, TILES.FOREST, "up", "down")
addMutualRule(TILES.GRASS, TILES.FOREST, "right", "left")

-- Forest next to Grass/Forest
addMutualRule(TILES.FOREST, TILES.FOREST, "up", "down")
addMutualRule(TILES.FOREST, TILES.FOREST, "right", "left")

-- Lava next to Lava
addMutualRule(TILES.LAVA, TILES.LAVA, "up", "down")
addMutualRule(TILES.LAVA, TILES.LAVA, "right", "left")

--rock next to rock
addMutualRule(TILES.ROCK, TILES.ROCK, "up", "down")
addMutualRule(TILES.ROCK, TILES.ROCK, "right", "left")

-- Mountain next to Rock
addMutualRule(TILES.MOUNTAIN, TILES.ROCK, "up", "down")
addMutualRule(TILES.MOUNTAIN, TILES.ROCK, "right", "left")

-- Mountain next to Lava
addMutualRule(TILES.MOUNTAIN, TILES.LAVA, "up", "down")
addMutualRule(TILES.MOUNTAIN, TILES.LAVA, "right", "left")

-- Lava next to Rock/Sand
addMutualRule(TILES.LAVA, TILES.ROCK, "up", "down")
addMutualRule(TILES.LAVA, TILES.ROCK, "right", "left")
addMutualRule(TILES.LAVA, TILES.SAND, "up", "down")
addMutualRule(TILES.LAVA, TILES.SAND, "right", "left")

-- Sand next to Rock
addMutualRule(TILES.SAND, TILES.ROCK, "up", "down")
addMutualRule(TILES.SAND, TILES.ROCK, "right", "left")

-- Build an array of all tile IDs for iteration.
local allTileIDs = {}
for key, value in pairs(TILES) do
    if type(value) == "number" then
        table.insert(allTileIDs, value)
    end
end

----------------------------
-- CHUNK & WORLD CONFIGURATION
----------------------------

local CHUNK_W, CHUNK_H = 40, 30   -- Number of cells per chunk in X and Y
local CELL_SIZE = 20              -- Pixel size of each cell

-- Table to hold all generated chunks.
local worldChunks = {}

-- Helper: Build a key string from chunk coordinates.
local function chunkKey(cx, cy)
    return cx .. "," .. cy
end

-- Helper: Convert a world coordinate to a chunk coordinate.
local function worldToChunk(pos, cellSize, chunkCount)
    return math.floor(pos / (cellSize * chunkCount))
end

----------------------------
-- WFC FUNCTIONS FOR EACH CHUNK
----------------------------

-- Propagate constraints within a chunk after collapsing a cell.
local function propagateChunk(chunk, startX, startY)
    local stack = {}
    local function addToStack(x, y)
        if x >= 1 and x <= CHUNK_W and y >= 1 and y <= CHUNK_H then
            local key = y * CHUNK_W + x
            if not stack[key] then
                stack[key] = {x = x, y = y}
            end
        end
    end

    addToStack(startX, startY - 1)
    addToStack(startX + 1, startY)
    addToStack(startX, startY + 1)
    addToStack(startX - 1, startY)

    local processedStack = {}
    while true do
        processedStack = {}
        for _, cellPos in pairs(stack) do
            table.insert(processedStack, cellPos)
        end
        if #processedStack == 0 then break end
        stack = {}
        for _, current in ipairs(processedStack) do
            local nx, ny = current.x, current.y
            local neighbor = chunk.grid[ny][nx]
            if not neighbor.collapsed then
                local firstNeighbor = true
                local possibleBasedOnNeighbors = {}
                local dx = {0, 1, 0, -1}
                local dy = {-1, 0, 1, 0}
                local oppositeDirs = {"down", "left", "up", "right"}
                for i = 1, 4 do
                    local sourceX = nx + dx[i]
                    local sourceY = ny + dy[i]
                    local sourceToNeighborDir = oppositeDirs[i]
                    if sourceX >= 1 and sourceX <= CHUNK_W and sourceY >= 1 and sourceY <= CHUNK_H then
                        local sourceCell = chunk.grid[sourceY][sourceX]
                        if sourceCell.collapsed then
                            local sourceTileID = next(sourceCell.possibilities)
                            local allowedBySource = {}
                            if rules[sourceTileID] then
                                for potentialID, ruleSet in pairs(rules[sourceTileID]) do
                                    if ruleSet[sourceToNeighborDir] then
                                        allowedBySource[potentialID] = true
                                    end
                                end
                            end
                            if firstNeighbor then
                                possibleBasedOnNeighbors = allowedBySource
                                firstNeighbor = false
                            else
                                for existing, _ in pairs(possibleBasedOnNeighbors) do
                                    if not allowedBySource[existing] then
                                        possibleBasedOnNeighbors[existing] = nil
                                    end
                                end
                            end
                        end
                    end
                end
                if not firstNeighbor then
                    local changed = false
                    for possibility, _ in pairs(neighbor.possibilities) do
                        if not possibleBasedOnNeighbors[possibility] then
                            neighbor.possibilities[possibility] = nil
                            neighbor.entropy = neighbor.entropy - 1
                            changed = true
                        end
                    end
                    if changed then
                        if neighbor.entropy == 0 then
                            print("Error: Contradiction at cell", nx, ny)
                            return
                        elseif neighbor.entropy == 1 then
                            -- **Fix:** Immediately flag cells with one possibility as collapsed.
                            neighbor.collapsed = true
                        end
                        addToStack(nx, ny - 1)
                        addToStack(nx + 1, ny)
                        addToStack(nx, ny + 1)
                        addToStack(nx - 1, ny)
                    end
                end
            end
        end
    end
end

-- Generate a new chunk using WFC.
local function generateChunk(cx, cy)
    local chunk = {}
    chunk.grid = {}
    for y = 1, CHUNK_H do
        chunk.grid[y] = {}
        for x = 1, CHUNK_W do
            local possibilities = {}
            for _, tileID in ipairs(allTileIDs) do
                possibilities[tileID] = true
            end
            chunk.grid[y][x] = {
                possibilities = possibilities,
                entropy = #allTileIDs,
                collapsed = false
            }
        end
    end

    -- Helper to collapse a cell with a given tile
local function collapseCell(cell, tileID)
    cell.possibilities = { [tileID] = true }
    cell.entropy = 1
    cell.collapsed = true
end

-- Look for neighboring chunks
local top = worldChunks[chunkKey(cx, cy - 1)]
local bottom = worldChunks[chunkKey(cx, cy + 1)]
local left = worldChunks[chunkKey(cx - 1, cy)]
local right = worldChunks[chunkKey(cx + 1, cy)]

-- Match top edge
if top then
    for x = 1, CHUNK_W do
        local neighborCell = top.grid[CHUNK_H] and top.grid[CHUNK_H][x]
        if neighborCell and neighborCell.collapsed then
            local tileID = next(neighborCell.possibilities)
            collapseCell(chunk.grid[1][x], tileID)
        end
    end
end

-- Match bottom edge
if bottom then
    for x = 1, CHUNK_W do
        local neighborCell = bottom.grid[1] and bottom.grid[1][x]
        if neighborCell and neighborCell.collapsed then
            local tileID = next(neighborCell.possibilities)
            collapseCell(chunk.grid[CHUNK_H][x], tileID)
        end
    end
end

-- Match left edge
if left then
    for y = 1, CHUNK_H do
        local neighborCell = left.grid[y] and left.grid[y][CHUNK_W]
        if neighborCell and neighborCell.collapsed then
            local tileID = next(neighborCell.possibilities)
            collapseCell(chunk.grid[y][1], tileID)
        end
    end
end

-- Match right edge
if right then
    for y = 1, CHUNK_H do
        local neighborCell = right.grid[y] and right.grid[y][1]
        if neighborCell and neighborCell.collapsed then
            local tileID = next(neighborCell.possibilities)
            collapseCell(chunk.grid[y][CHUNK_W], tileID)
        end
    end
end

-- After seeding edge cells, propagate all collapsed ones
for y = 1, CHUNK_H do
    for x = 1, CHUNK_W do
        local cell = chunk.grid[y][x]
        if cell.collapsed then
            propagateChunk(chunk, x, y)
        end
    end
end




    local function findLowestEntropyCell()
        local minEntropy = #allTileIDs + 1
        local candidate = nil
        for y = 1, CHUNK_H do
            for x = 1, CHUNK_W do
                local cell = chunk.grid[y][x]
                if not cell.collapsed and cell.entropy > 1 and cell.entropy < minEntropy then
                    minEntropy = cell.entropy
                    candidate = {x = x, y = y}
                end
            end
        end
        return candidate
    end

    local candidate = findLowestEntropyCell()
    while candidate do
        local cell = chunk.grid[candidate.y][candidate.x]
        local possibleNow = {}
        for possibility, _ in pairs(cell.possibilities) do
            table.insert(possibleNow, possibility)
        end
        if #possibleNow == 0 then
            print("Chunk generation contradiction at", candidate.x, candidate.y)
            break
        end
        local chosenTile = possibleNow[math.random(#possibleNow)]
        cell.possibilities = { [chosenTile] = true }
        cell.entropy = 1
        cell.collapsed = true
        propagateChunk(chunk, candidate.x, candidate.y)
        candidate = findLowestEntropyCell()
    end

    return chunk
end

-- Retrieve an existing chunk or generate a new one at (cx, cy)
local function getChunk(cx, cy)
    local key = chunkKey(cx, cy)
    if not worldChunks[key] then
        worldChunks[key] = generateChunk(cx, cy)
    end
    return worldChunks[key]
end

----------------------------
-- PLAYER SETUP
----------------------------

local player = {
    x = 200,      -- Starting world X coordinate
    y = 200,      -- Starting world Y coordinate
    speed = 150   -- Movement speed in pixels per second
}

----------------------------
-- LOVE2D CALLBACKS
----------------------------

function love.load()
    love.window.setTitle("Endless WFC World")
    love.window.setMode(800, 600)  -- Set window size
    math.randomseed(os.time())
end

function love.update(dt)
    if love.keyboard.isDown("w", "up") then
        player.y = player.y - player.speed * dt
    end
    if love.keyboard.isDown("s", "down") then
        player.y = player.y + player.speed * dt
    end
    if love.keyboard.isDown("a", "left") then
        player.x = player.x - player.speed * dt
    end
    if love.keyboard.isDown("d", "right") then
        player.x = player.x + player.speed * dt
    end
end

function love.draw()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    -- Center the view on the player.
    love.graphics.push()
    love.graphics.translate(screenW/2 - player.x, screenH/2 - player.y)
    
    local cellSize = CELL_SIZE
    local chunkPixelW = CHUNK_W * cellSize
    local chunkPixelH = CHUNK_H * cellSize
    
    -- Determine which chunk the player is in.
    local currentChunkX = math.floor(player.x / (cellSize * CHUNK_W))
    local currentChunkY = math.floor(player.y / (cellSize * CHUNK_H))
    
    -- Draw a 3x3 grid of chunks around the current chunk.
    for cx = currentChunkX - 1, currentChunkX + 1 do
        for cy = currentChunkY - 1, currentChunkY + 1 do
            local chunk = getChunk(cx, cy)
            local offsetX = cx * chunkPixelW
            local offsetY = cy * chunkPixelH
            for y = 1, CHUNK_H do
                for x = 1, CHUNK_W do
                    local cell = chunk.grid[y][x]
                    local drawX = offsetX + (x - 1) * cellSize
                    local drawY = offsetY + (y - 1) * cellSize
                    local tileID = next(cell.possibilities) or 0
                    local color = COLORS[tileID] or COLORS.UNCOLLAPSED
                    love.graphics.setColor(color)
                    love.graphics.rectangle("fill", drawX, drawY, cellSize - 1, cellSize - 1)
                end
            end
        end
    end

    -- Draw the player. After translation the player's world position ends up centered.
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", player.x, player.y, 5)
    love.graphics.pop()

    -- HUD: Instructions.
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Use WASD or arrow keys to move", 10, 10)
end
