
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

    constructor: (@obj, cwidth, cheight, @renderContext, @world, options={}) ->
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

      $.extend true, @, $.si.smallimap.defaults, options

      @grid = @generateGrid @width, @height

    run: =>
      @refresh()

    refresh: =>
      now = new Date().getTime()
      dt = now - @lastRefresh
      @lastRefresh = now

      ongoingEvents = []
      for event in @eventQueue when event.refresh dt
        ongoingEvents.push event
      @eventQueue = ongoingEvents

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
        setRadius: (radius) =>
          @setRadius x, y, radius
        setColor: (color) =>
          @setColor x, y, color

      return newDot

    longToX: (longitude) ->
      Math.floor((longitude + 180) * @width / 360 + 0.5) # <- round

    latToY: (latitude) ->
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

      if sunSet.isDaylight(now.getHours()) or latitude >= 69
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
        push = (x, dt) =>
          dot = @grid[x][0]
          r = dot.initial.radius

          setDots = (r) =>
            for y in [0..@height - 1]
              @setRadius x, y, r

          @eventQueue.push =>
            setDots r + dt
            setTimeout =>
              setDots r
              @eventQueue.push =>
                push((x + 1) % @width, dt)
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

    enqueueEvent: (event) =>
      event.init()
      @eventQueue.push(event)

    addMapIcon: (title, label, iconUrl, longitude, latitude) =>
      @mapIcons.push new MapIcon(title, label, iconUrl, @longToX, @latToY)


  class Effect

    constructor: (@dot, @duration, options) ->
      @timeElapsed = 0
      @easing = options.easing || @linearEasing
      @callback = options.callback

    linearEasing: (progress) ->
      progress

    update: (dt) =>
      @timeElapsed += dt
      @refresh Math.min(1, @easing(@timeElapsed/@duration))
      if @timeElapsed > @duration
        @callback?()
        false
      else
        true

    refresh: (progress) =>
      "unimplemented"

  class RadiusEffect extends Effect
    constructor: (dot, duration, options) ->
      super dot, duration, options
      @startRadius = options.startRadius
      @endRadius = options.endRadius

    refresh: (progress) =>
      @dot.setRadius @endRadius * progress + @startRadius * (1 - progress)

  class ColorEffect extends Effect
    constructor: (dot, duration, options) ->
      super dot, duration, options
      @startColor = options.startColor
      @endColor = options.endColor

    refresh: (progress) =>
      start = new Color(@startColor.rgbString())
      @dot.setColor start.mix(@endColor, progress)

  class DelayEffect extends Effect
    constructor: (dot, duration, options) ->
      super dot, duration, options

    refresh: (progress) =>
      "nothing to do"

  class Event
    constructor: (@smallimap, @callback) ->
      @queue = []

    enqueue: (effect) =>
      @queue.push effect

    init: () =>
      "no init, dude"

    refresh: (dt) =>
      currentEffects = @queue.splice(0)
      @queue = []
      for effect in currentEffects
        if effect.update dt
          @queue.push effect
      @queue.length > 0

  class BlipEvent extends Event
    constructor: (smallimap, options) ->
      super smallimap, options.callback
      @latitude = options.latitude
      @longitude = options.longitude
      @color = new Color(options.color or "#336699")
      @eventRadius = options.eventRadius || 8
      @duration = options.duration or 1024
      #@weight = options.weight || 0.5

    init: () =>
      x = @smallimap.longToX @longitude
      y = @smallimap.latToY @latitude

      for i in [-@eventRadius..@eventRadius]
        for j in [-@eventRadius..@eventRadius]
          nx = x + i
          ny = y + j
          d = Math.sqrt(i * i + j * j)
          if d < @eventRadius and @smallimap.grid[nx] and @smallimap.grid[nx][ny]
            dot = @smallimap.grid[nx][ny]
            @initEventsForDot nx, ny, d, dot

    initEventsForDot: (nx, ny, d, dot) =>
      delay = @duration * d/@eventRadius
      duration = @duration - delay
      startColor = dot.initial.color
      startRadius = dot.initial.radius
      endColor = new Color(@color.rgbString())
      endRadius = (@smallimap.dotRadius - startRadius) / (d+1) + startRadius
      if duration > 0
        @enqueue new ColorEffect(dot, duration,
          startColor: startColor
          endColor: endColor
          callback: =>
            @enqueue new ColorEffect(dot, duration, { startColor: endColor, endColor: startColor })
        )
        @enqueue new RadiusEffect(dot, duration,
          startRadius: startRadius
          endRadius: endRadius
          callback: =>
            @enqueue new RadiusEffect(dot, duration, { startRadius: endRadius, endRadius: startRadius })
        )

  class MapIcon
    constructor: (mapContainer, @title, @label, @iconUrl, @x, @y) ->
      @init()

    init: =>
      iconHtml = """
        <div class=\"smallipop\">
          <img src=\"#{@iconUrl}\" alt=\"#{@title}\"/>
          <div class=\"smallipopHint\">
            <b class=\"smallimap-icon-title\">#{@title}</b><br/>
            <p class=\"smallimap-icon-label\">#{@label}</p>
          </div>
        </div>
      """

      @iconObj = $(iconHtml).css
        left: @x
        top: @y

      mapContainer.append @iconObj
      @iconObj.smallipop()

    remove: =>
      @iconObj.remove()

  $.si.smallimap.effects =
    Effect: Effect
    ColorEffect: ColorEffect
    RadiusEffect: RadiusEffect

  $.si.smallimap.events =
    Event: Event
    BlipEvent: BlipEvent

  $.fn.smallimap = (options={}) ->
    options = $.extend {}, $.si.smallimap.defaults, options

    return @.each ->
      # Initialize each trigger, create id and bind events
      self = $(@)
      canvas = @
      ctx = canvas.getContext '2d'
      smallimap = new Smallimap(self, canvas.width, canvas.height, ctx, smallimapWorld, options)

      self.data 'api', smallimap

)(jQuery)
