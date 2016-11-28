local imgPath = "img.jpg"

-- Canvases
local workingCanvas = nil
local targetCanvas = nil

local targetData = nil

-- Processing values
local fitness = 0
local numberOfChanges = 0
local polygons
local cycle = 0

-- Working constants
local numberOfPolygons = 100
local numberOfVertices = 10
local colorMutRange = 50
local vertexMutRangeQ = 0.3
local numberOfMutationsPerCycle = 1

local gcCallPerCycles = 1000 -- call GC after N cycles of updating

function randomColor()
	return math.random(0, 255)
end

function createPolygons(maxX, maxY)
	local p = {}
	
	for i = 1, numberOfPolygons do
		p[i] = {}
		
		p[i].color = { 
			r = randomColor(),
			g = randomColor(),
			b = randomColor(),
			a = 0, -- invisible
		}
		p[i].vertices = {}
		
		-- Create list of vertices in format for Love2D
		-- Eg, { 1:x1, 2:y1, 3:x2, 4:y2, ...}
		for v = 1, numberOfVertices*2, 2 do
			p[i].vertices[v] = math.random(0, maxX)
			p[i].vertices[v+1] = math.random(0, maxY)
		end
	end
	
	return p
end

function love.load()
	math.randomseed(os.time())
	
	local img = love.graphics.newImage(imgPath)
	local w, h = img:getDimensions()
	
	workingCanvas = love.graphics.newCanvas(w, h)
	targetCanvas = love.graphics.newCanvas(w, h)
	
	-- Set window proportions
	love.window.setMode(w*2, h)
	polygons = createPolygons(w, h)
	
	-- Draw the image into target canvas
	love.graphics.setCanvas(targetCanvas)
	love.graphics.draw(img)
	love.graphics.setCanvas()
	
	-- Create target data
	targetData = targetCanvas:newImageData()
end

function drawPolygonsIntoWorkingCanvas()
	love.graphics.setCanvas(workingCanvas)
	love.graphics.clear()
	love.graphics.setBlendMode("alpha")
	
	love.graphics.setColor(0, 0, 0)
	
	-- First, make the canvas black
	love.graphics.rectangle("fill", 0, 0, 
		workingCanvas:getWidth(), workingCanvas:getHeight())
		
	-- Draw polygons into canvas
	for i = 1, numberOfPolygons do
		local c = polygons[i].color
		love.graphics.setColor(c.r, c.g, c.b, c.a)
		love.graphics.polygon("fill", polygons[i].vertices)
	end
	
	-- Unset canvas
	love.graphics.setCanvas()
	love.graphics.setColor(255, 255, 255, 255)
end

-- Compare working canvas with target canvas pixel by pixel
-- @return fitness (percentage of same pixels in both canvases)
function compareCanvases()
	-- Let's assume that both canvases have same proportions
	local w, h = workingCanvas:getDimensions()
	
	-- Very memory consuming, I know...
	-- But there is no simple other way
	local workingData = workingCanvas:newImageData()
	
	local fitness = 0
	
	for x = 0, w-1 do
		for y = 0, h-1 do
			local r1, g1, b1 = workingData:getPixel(x, y)
			local r2, g2, b2 = targetData:getPixel(x, y)
			fitness = fitness + 
				math.abs(r1-r2) + math.abs(g1-g2) + math.abs(b1-b2)
		end
	end
	
	return (1 - (fitness/(w*h*255*3))) * 100
end

function setWithinRange(v, from, to)
	if v < from then
		return from
	elseif v > to then
		return to
	else
		return v
	end
end

function mutateColorValue(v)
	return setWithinRange(v + math.random(-colorMutRange, colorMutRange), 0, 255)
end

function mutateVertex(x, y)
	local w, h = workingCanvas:getDimensions()
	local horRange = vertexMutRangeQ * w
	local verRange = vertexMutRangeQ * h
	
	return setWithinRange(x + math.random(-horRange, horRange), 0, w),
		setWithinRange(y + math.random(-verRange, verRange), 0, h)
end

function mutate()
	local p = polygons[math.random(1, numberOfPolygons)]
	local vertexIndex = math.random(1, numberOfVertices)*2 - 1
	
	-- Color before mutation
	local ro, go, bo, ao = p.color.r, p.color.g, p.color.b, p.color.a
	
	-- Vertex before mutation
	local x, y = p.vertices[vertexIndex], p.vertices[vertexIndex+1]
	
	-- Mutate them, either color or vertex, not both!
	if math.random() < 0.5 then
		p.color.r = mutateColorValue(ro)
		p.color.g = mutateColorValue(go)
		p.color.b = mutateColorValue(bo)
		p.color.a = mutateColorValue(ao)
	else
		p.vertices[vertexIndex], p.vertices[vertexIndex+1] = 
			mutateVertex(x, y)
	end
	
	drawPolygonsIntoWorkingCanvas()
	
	local proposedFitness = compareCanvases()
	
	if proposedFitness <= fitness then
		-- Bad changes...
		p.color.r, p.color.g, p.color.b, p.color.a = ro, go, bo, ao
		p.vertices[vertexIndex], p.vertices[vertexIndex+1] = x, y
	else
		-- Keep the changes
		fitness = proposedFitness
		numberOfChanges = numberOfChanges + 1
	end
end

local stopComputing = false

function love.update(deltaTime)
	cycle = cycle + 1
	
	if cycle >= gcCallPerCycles then
		cycle = 0
		collectgarbage("restart")
		collectgarbage("collect")
		collectgarbage("stop")
	end
	
	if stopComputing == false then
		mutate()
	end
end

function love.draw()
	love.graphics.draw(workingCanvas, 0, 0)
	love.graphics.draw(targetCanvas, workingCanvas:getWidth(), 0)
	love.graphics.print("Fitness: " .. fitness, 10, 0)
	love.graphics.print("Number of changes: " .. numberOfChanges, 10, 20)
end

local imageOutput = "output.png"

function love.quit()
	if stopComputing then
		-- Data has been printed already
		return false
	end
	
	for i = 1, numberOfPolygons do
		io.write("Polygon number: ", i, "\n")
		
		local c = polygons[i].color
		
		io.write("\tColor: ")
		io.write("r: ", c.r)
		io.write(" g: ", c.g)
		io.write(" b: ", c.b)
		io.write(" a: ", c.a, "\n")
		
		local ver = polygons[i].vertices
		
		io.write("\tVertices: ")
		for v = 1, numberOfVertices*2, 2 do
			io.write("[", ver[v], ", ", ver[v+1], "] ")
		end
		
		io.write("\n")
	end
	
	-- Save working canvas
	workingCanvas:newImageData():encode("png", imageOutput)
	
	print("\nImage has been saved to", love.filesystem.getSaveDirectory(), "->", imageOutput)
	print("Fitness: ", fitness, " Number of changes: ", numberOfChanges)
	
	stopComputing = true
	return true
end