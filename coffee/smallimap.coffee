
(($) ->
  $.si ||= {}
  $.si.smallimap =
    version: '0.1'
    defaults:
      dotRadius: 4
      fps: 20
      width: 1000
      height: 500
      colors:
        lights: ["#fdf6e3", "#fafafa", "#dddddd", "#93a1a1", "#839496"]
        darks: ["#002b36", "#073642", "#586e75", "#657b83"]
        land:
          day: (smallimap) ->
            smallimap.colors.lights.slice(1).concat(smallimap.colors.darks.slice(1).reverse())
          night: (smallimap) ->
            smallimap.colors.land.day().reverse()

  class Smallimap

    constructor: (@obj, cwidth, cheight, @renderContext, @world, options={}) ->
      $.extend true, @, options

      @dotDiameter = @dotRadius * 2
      @width = cwidth / @dotDiameter
      @height = cheight / @dotDiameter
      @lastX = -1
      @lastY = -1
      @dirtyXs = undefined
      @eventQueue = []
      @lastRefresh = 0
      @mapIcons = []

      @grid = @generateGrid @width, @height

    run: =>
      @refresh()

    refresh: =>
      now = new Date().getTime()
      dt = now - @lastRefresh
      @lastRefresh = now

      # Refresh event queue
      ongoingEvents = []
      for event in @eventQueue when event.refresh dt
        ongoingEvents.push event
      @eventQueue = ongoingEvents

      # Render dirty dots
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

    enqueueEvent: (event) =>
      event.init()
      @eventQueue.push(event)

    addMapIcon: (title, label, iconUrl, longitude, latitude) =>
      longitude = parseFloat longitude
      latitude = parseFloat latitude

      mapX = @longToX(longitude) * @dotDiameter + @dotRadius
      mapY = @latToY(latitude) * @dotDiameter + @dotRadius

      @mapIcons.push new MapIcon(@obj, title, label, iconUrl, mapX, mapY)

  class Effect

    constructor: (@dot, @duration, options) ->
      @timeElapsed = 0
      @easing = options.easing || easing.linear
      @callback = options.callback

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
    constructor: (@smallimap, options) ->
      @callback = options.callback
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

  class GeoEvent extends Event
    constructor: (smallimap, options) ->
      super smallimap, options
      @latitude = options.latitude
      @longitude = options.longitude
      @x = @smallimap.longToX @longitude
      @y = @smallimap.latToY @latitude

  class GeoAreaEvent extends GeoEvent
    constructor: (smallimap, options) ->
      super smallimap, options
      @eventRadius = options.eventRadius || 8

    init: () =>
      for i in [-@eventRadius..@eventRadius]
        for j in [-@eventRadius..@eventRadius]
          nx = @x + i
          ny = @y + j
          d = Math.sqrt(i * i + j * j)
          if d < @eventRadius and @smallimap.grid[nx] and @smallimap.grid[nx][ny]
            dot = @smallimap.grid[nx][ny]
            @initEventsForDot nx, ny, d, dot

  class BlipEvent extends GeoAreaEvent
    constructor: (smallimap, options) ->
      super smallimap, options
      @color = new Color(options.color or "#336699")
      @duration = options.duration or 1024
      @weight = options.weight || 1

    initEventsForDot: (nx, ny, d, dot) =>
      delay = @duration * d/@eventRadius
      duration = @duration - delay
      startColor = dot.initial.color
      startRadius = dot.initial.radius
      endColor = new Color(@color.rgbString()).mix(startColor, d/@eventRadius*@weight)
      endRadius = (@smallimap.dotRadius - startRadius)*@weight/(d+1) + startRadius
      if duration > 0
        @enqueue new DelayEffect(dot, delay,
          callback: =>
            @enqueue new ColorEffect(dot, duration,
              startColor: startColor
              endColor: endColor
              easing: easing.cubic
              callback: =>
                @enqueue new ColorEffect(dot, duration*8,
                  startColor: endColor
                  endColor: startColor
                  easing: easing.inverse easing.cubic
                )
            )
        )
        @enqueue new DelayEffect(dot, delay,
          callback: =>
            @enqueue new RadiusEffect(dot, duration,
              startRadius: startRadius
              endRadius: endRadius
              easing: easing.cubic
              callback: =>
                @enqueue new RadiusEffect(dot, duration*8, { startRadius: endRadius, endRadius: startRadius })
            )
        )

  class LensEvent extends GeoEvent
    constructor: (smallimap, options) ->
      super smallimap, options
      @delay = options.delay or 0
      @duration = options.duration or 1024
      @weight = options.weight || 1
      @isOut = options.fade == "out"

    init: () =>
      dot = @smallimap.grid[@x][@y]
      duration = @duration
      startRadius = dot.initial.radius
      endRadius = (@smallimap.dotRadius - startRadius)*@weight + startRadius
      if @isOut # swap the radius
        startRadius = endRadius
        endRadius = dot.initial.radius
      @enqueue new DelayEffect(dot, @delay,
        callback: =>
          @enqueue new RadiusEffect(dot, @duration,
            startRadius: startRadius
            endRadius: endRadius
            easing: easing.quadratic
          )
      )

  class MapIcon
    constructor: (@mapContainer, @title, @label, @iconUrl, @x, @y) ->
      @initialOpacity = 0.7
      @zoom = 1.5
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
      @iconObj = $ iconHtml

      @iconObjImage = @iconObj.find 'img'
      @iconObjImage.load =>
        @width = @iconObjImage.get(0).width or 24
        @height = @iconObjImage.get(0).height or 24

        @iconObjImage.attr
          width: @width
          height: @height
        .css
          width: '100%'
          height: '100%'

        @iconObj.css
          position: 'absolute'
          left: @x - @width / 2
          top: @y - @height / 2
          opacity: 0
        .bind 'mouseover mouseout', @onHover

        @mapContainer.append @iconObj
        @iconObj.fadeTo(200, @initialOpacity).smallipop
          theme: 'black'

    onHover: (e) =>
      if e.type is 'mouseover'
        @iconObj.stop().animate
            opacity: 1
            left: @x - (@width * @zoom) / 2
            top: @y - (@height * @zoom) / 2
            width: @width * @zoom
            height: @height * @zoom
          ,100
      else
        @iconObj.stop().animate
            opacity: @initialOpacity
            left: @x - @width / 2
            top: @y - @height / 2
            width: @width
            height: @height
          ,200

    remove: =>
      @iconObj.remove()

  easing =
    linear: (progress) ->
      progress
    quadratic: (progress) ->
      progress*progress
    cubic: (progress) ->
      progress*progress*progress
    inverse: (easing) ->
      (progress) ->
        1 - easing(1 - progress)

  $.si.smallimap.effects =
    Effect: Effect
    ColorEffect: ColorEffect
    RadiusEffect: RadiusEffect

  $.si.smallimap.events =
    Event: Event
    BlipEvent: BlipEvent
    LensEvent: LensEvent

  $.si.smallimap.easing = easing

  $.fn.smallimap = (options={}) ->
    options = $.extend {}, $.si.smallimap.defaults, options

    return @.each ->
      # Initialize each trigger, create id and bind events
      self = $(@).css
        position: 'relative'

      canvasObj = $ '<canvas>'
      canvasObj.attr
        width: options.width
        height: options.height

      # Append canvas to dom
      self.append canvasObj

      # Get render context from canvas
      canvas = canvasObj.get 0
      ctx = canvas.getContext '2d'
      smallimap = new Smallimap(self, canvas.width, canvas.height, ctx, smallimapWorld, options)

      self.data 'api', smallimap

)(jQuery)
