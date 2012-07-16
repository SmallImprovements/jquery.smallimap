
(($) ->
  $.si ||= {}
  $.si.smallimap =
    version: '0.1'
    defaults:
      colors:
        lights: ["#fdf6e3", "#eee8d5", "#b8b0aa", "#93a1a1", "#839496"]
        darks: ["#002b36", "#073642", "#586e75", "#657b83"]
        land:
          day: (smallimap) ->
            smallimap.colors.lights.slice(1).concat(smallimap.colors.darks.slice(1).reverse())
          night: (smallimap) ->
            smallimap.colors.land.day().reverse()

  class Smallimap

    constructor: (cwidth, cheight, renderContext, world, options={}) ->
      @world = world
      @dotRadius = 3.2
      @dotDiameter = @dotRadius * 2
      @width = cwidth / @dotDiameter
      @height = cheight / @dotDiameter
      @lastX = -1
      @lastY = -1
      @dirtyXs = undefined
      @eventQueue = []
      @lastRefresh = 0
      @fps = 20
      @renderContext = renderContext

      $.extend true, @, $.si.smallimap.defaults, options

      @grid = @generateGrid @width, @height

    run: =>
      @refresh()

    refresh: =>
      now = new Date()

      for i in [0..@eventQueue.length] when i
        event = @eventQueue.shift()
        event now

      unless @dirtyXs
        @dirtyXs = []
        @dirtyXs[x] = true for x in [0..@width - 1]

      for x in [0..@width - 1]
        if @dirtyXs[x]
          @dirtyXs[x] = false
          @render(x,y) for y in [0..@height - 1] when @grid[x][y].dirty

      # Request next animation frame for rendering
      requestAnimationFrame @refresh

    generateGrid: (width, height) =>
      grid = []

      for x in [0..width - 1]
        for y in [0..height - 1]
          grid[x] ||= []
          grid[x][y] = @dot(x, y, @landinessOf(x, y))

      return grid

    dot: (x, y, landiness) =>
      newDot =
        x: x
        y: y
        landiness: landiness
        initial:
          color: @colorFor @xToLong(x), @yToLat(y), landiness
          radius: @dotRadius * 0.64
        target : {}
        dirty: true

      return newDot

    longToX: (longitude) ->
      Math.floor((longitude + 180) * @width / 360 + 0.5) # <- round

    latToX: (latitude) ->
      Math.floor((-latitude + 90) * @height / 180 + 0.5) # <- round

    xToLong: (x) ->
      Math.floor(x * 360 / @width - 180 + 0.5)

    yToLat: (y) ->
      - Math.floor(y * 180 / @height - 90 + 0.5)

    colorFor: (longitude, latitude, landiness) =>
      darkness = landiness * landiness
      now = new Date()
      sunSet = new SunriseSunset(now.getYear(), now.getMonth() + 1, now.getDate(), latitude, longitude)
      landColors = @colors.land.day(@)
      idx = Math.floor(darkness * (landColors.length - 2))

      if sunSet.isDaylight now.getHours()
        new Color(landColors[idx])
      else
        new Color(landColors[idx + 1])

    convertToWorldX: (x) =>
      Math.floor(x * @world.length / @width)

    convertToWorldY: (y) =>
      Math.floor(y * @world[0].length / @height)

    landinessOf: (x, y) =>
        worldXStart = @convertToWorldX x
        worldXEnd = @convertToWorldX(x + 1) - 1
        worldYStart = @convertToWorldY y
        worldYEnd = @convertToWorldY(y + 1) - 1
        totalCount = 0
        existsCount = 0

        for i in [worldXStart..worldXEnd]
          for j in [worldYStart..worldYEnd]
            totalCount += 1
            existsCount += 1 if @world[i] and @world[i][j]

        return existsCount / totalCount

    render: (x, y, millis) =>
      dot = @grid[x][y]

      color = dot.target.color or dot.initial.color
      radius = dot.target.radius or dot.initial.radius

      @renderContext.clearRect(x * @dotDiameter, y * @dotDiameter, @dotDiameter, @dotDiameter)
      @renderContext.fillStyle = color.rgbString()
      @renderContext.beginPath()
      @renderContext.arc(x * @dotDiameter + @dotRadius, y * @dotDiameter + @dotRadius, radius, 0, Math.PI * 2, true)
      @renderContext.closePath()
      @renderContext.fill()

      dot.dirty = false
      dot.target = {}

    markDirty: (x, y) =>
      @dirtyXs[x] = true if @dirtyXs
      @grid[x][y].dirty = true

    reset: (x, y) =>
      @markDirty x, y

    setRadius: (x, y, r) =>
      target = @grid[x][y].target

      if target.radius
          target.radius = (target.radius + r) / 2
      else
          target.radius = r

      @markDirty x, y

    setColor: (x, y, color) =>
      target = @grid[x][y].target

      if target.color
          target.color = target.color.mix color
      else
        target.color = color

      @markDirty x, y

    triggerOverlay: =>
        y = 0
        push = (x, diff) =>
          dot = @grid[x][0]
          r = dot.initial.radius

          setDots = (r) =>
            for y in [0..@height - 1]
              @setRadius x, y, r

          @eventQueue.push =>
            setDots r + diff
            setTimeout =>
              setDots r
              @eventQueue.push =>
                push((x + 1) % @width, diff)
            , 1000 / @width * 8

        push(0, 0.5) for y in [0..@height - 1]


    newMouseHover: (px, py) =>
      x = Math.floor(px / @dotDiameter)
      y = Math.floor(py / @dotDiameter)
      radius = 2
      pushDown = (x, y, initial, target) ->
        true
        # eventQueue.push(pub.events.changeRadius(x, y, initial, target, 128, function () {}))

      # Check we're not out of bounds
      if @grid[x] and @grid[x][y]
        if @lastX isnt x and @lastY isnt y
          dot = @grid[x][y]
          for i in [-radius..radius]
              for j in [-radius..radius]
                d = Math.sqrt(i * i + j * j)
                if d < radius
                  pushDown(x + i, y + j, dot.initial.radius, 2)

          lastX = x
          lastY = y

    createChangers: (x, y, startColor, targetColor, colorWeight, startRadius, targetRadius, delay, length) =>
      setTimeout =>
        @eventQueue.push(@events.changeColor(@, x, y, startColor, targetColor, colorWeight, Math.min(512, length), =>
          @eventQueue.push(@events.changeColor(@, x, y, targetColor, startColor, 1, length, -> true))
        ))

        @eventQueue.push(@events.changeRadius(@, x, y, startRadius, targetRadius, Math.min(512, length), =>
          @eventQueue.push(@events.changeRadius(@, x, y, targetRadius, startRadius, length, -> true))
        ))
      , delay

    # { longitude: , latitude: , color: String (z.B. "#ff0088"), weight: [0..1], length: [in millis], radius: Int}
    newEvent: (event) =>
      x = @longToX event.longitude
      y = @latToX event.latitude
      radius = event.radius or 5

      for i in [-radius..radius]
        for j in [-radius..radius]
          nx = x + i
          ny = y + j
          d = Math.sqrt(i * i + j * j)

          if nx >= 0 and ny >= 0 and nx < @width and ny < @height and d < radius
            dot = @grid[nx][ny]
            delay = event.length * (d / radius)
            length = event.length - delay
            targetColor = new Color(event.color)
            targetRadius = (@dotRadius - dot.initial.radius) / (d + 1) + dot.initial.radius
            if length > 0
              @createChangers(nx, ny, dot.initial.color, targetColor, 1 - d / radius, dot.initial.radius, targetRadius, delay, length)

    events:
      changeColor: (smallimap, x, y, start, target, weight, length, onComplete) ->
        startTime = new Date().getTime()

        updater = (now) ->
          diff = now.getTime() - startTime
          frameWeight = weight * diff / length

          smallimap.setColor x, y, new Color(start.rgbString()).mix(target, weight)

          if diff < length
            smallimap.eventQueue.push updater
          else
            onComplete()

        return updater

      changeRadius: (smallimap, x, y, start, target, length, onComplete) ->
        startTime = new Date().getTime()

        updater = (now) ->
          diff = now.getTime() - startTime
          if(diff < length)
            smallimap.setRadius x, y, target * diff / length + start * (1 - diff / length)
            smallimap.eventQueue.push updater
          else
            smallimap.setRadius x, y, target
            onComplete()

        return updater

  $.fn.smallimap = (options={}) ->
    options = $.extend {}, $.si.smallimap.defaults, options

    return @.each ->
      # Initialize each trigger, create id and bind events
      self = $(@)
      canvas = @
      ctx = canvas.getContext '2d'
      smallimap = new Smallimap(canvas.width, canvas.height, ctx, smallimapWorld, options)

      self.data 'api', smallimap

)(jQuery)
