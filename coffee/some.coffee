###!
  Sonic Metrics client
  http://www.sonicmetrics.com

  Licensed under the MIT (http://www.opensource.org/licenses/mit-license.php) license.

  @author Sebastian Helzle (sebastian@helzle.net)
###

(($) ->
  $.some ||=
    version: '0.2.0'
    debug: true
    defaults:
      sourceId: 'SonicMetricClient'
      soundEnabled: true
      useLocalStorage: true
      useLastKeyOnRequests: true
      requireLogin: false
      animationSpeed: 150
      alertTimeout: 3000
      pollingInterval: 15000
      clientComputationPollingOffset: 1000
      minEventSchedulingDistance: 40
      serverUrl: 'http://localhost:8080'
      loginPath: 'login'
      registerPath: 'register'
      getEventsPath: 'events'
      createEventPath: 'post'
      getServerTime: 'time'
      alertsContainerId: 'sonicMetricsAlerts'
      highlightColor: '#63f'
      listeners: []

  # Extend array to get last item
  unless Array.prototype.last
    Array.prototype.last = ->
      @[@length - 1]

  # Basic logging function for debugging
  log = (message) ->
    caller = 'DOM'
    if arguments.callee.caller.toString().match(/function ([^\(]+)/)
      caller = arguments.callee.caller.toString().match(/function ([^\(]+)/)[1]
    window.console?.log("SOME [#{caller}]: #{message}") if $.some.debug?

  # Sonic Metrics client class
  class $.some.SonicMetricsClient

    constructor: (id, options={}) ->
      @id = id
      @pollingTimeoutId = -1
      @loggedIn = false
      @username = undefined
      @password = undefined
      @serverTimedelta = 0
      @paused = false
      @soundFormat = 'mp3'

      $.extend true, @, $.some.defaults, options

      @alertsContainer = $('#' + @alertsContainerId)

    # Get the current unix time
    getCurrentTime: ->
      new Date().getTime()

    # Get the absolute path for server uris
    getUrlForPath: (path, jsonp=false) =>
      url = "#{@serverUrl}/#{path}"
      if jsonp then url + "?callback=?" else url

    getUrlForClient: ->
      ''

    updateListenerList: (listeners) ->
      true

    guidGenerator: ->
      S4 = ->
         (((1+Math.random())*0x10000)|0).toString(16).substring(1)
      (S4()+S4()+"-"+S4()+"-"+S4()+"-"+S4()+"-"+S4()+S4()+S4())

    hasLocalStorage: =>
      if Modernizr?.localstorage and @useLocalStorage
        log 'Localstorage enabled'
        true
      else
        log 'Localstorage disabled'
        false

    init: =>
      # Try to get listeners and other data from local storage
      if @hasLocalStorage()
        storageData = JSON.parse localStorage.getItem('sonicMetricsData')

        if storageData
          log 'Retrieved data from local storage'
          log storageData

          @listeners = storageData.listeners if storageData.listeners?.length
          @username = storageData.username if storageData.username?
          @password = storageData.password if storageData.password?

          # Update listeners in frontend
          @updateListenerList @listeners

      # Get servertime
      @requestServerTime()

      # Add events to window for pausing the client when the window is inactive
      $(window).blur(@setPaused).focus(@setRunning)

      # Check if browser can handle audio
      if @soundEnabled
        if Modernizr?.audio?.ogg?
          log 'Ogg support for this browser is enabled'
          @soundFormat = 'ogg'
        else if Modernizr?.audio?.mp3?
          log 'Mp3 support for this browser is enabled'
        else
          @soundEnabled = false
          @feedback 'Your browser does not support our audio player at this time :-('

      @

    run: =>
      return if @requireLogin and not @loggedIn

      # Start polling the server
      @pollServer()

      @

    setPaused: =>
      log 'Client paused'
      @paused = true

    setRunning: =>
      log 'Client running'
      @paused = false

    storeData: =>
      log 'Storing data in local storage'
      storageData =
        listeners: @listeners
        username: @username
        password: @password

      localStorage.setItem 'sonicMetricsData', JSON.stringify(storageData)

    toggleSound: =>
      @soundEnabled = not @soundEnabled

    pollServer: =>
      return if @requireLogin and not @loggedIn

      unless @paused
        # Get new events from the server when the browser has time for it
        if window.requestAnimationFrame
          requestAnimationFrame @getEvents
        else
          @getEvents()

      # Init the next polling event
      @pollingTimeoutId = window.setTimeout @pollServer, @pollingInterval - @clientComputationPollingOffset

    feedback: (message, type='success') =>
      log message
      alert = $ "<div style=\"display:none;\" class=\"alert alert-#{type}\">#{message}</div>"

      @alertsContainer.append alert
      alert.show @animationSpeed

      # Hide alert after a while
      window.setTimeout =>
          alert.hide @animationSpeed, alert.remove
        , @alertTimeout

    scheduleSound: (listener, scheduledTimeout) =>
      return unless @soundEnabled

      log "Scheduling sound for listener #{listener.name} and offset #{scheduledTimeout}"
      window.setTimeout =>
          @play listener.sound if @soundEnabled
        , scheduledTimeout

    scheduleHighlight: (listener, scheduledTimeout) =>
      log "Scheduling highlight for listener #{listener.name} and offset #{scheduledTimeout}"
      window.setTimeout =>
          $("#listener-#{listener.id}").animateHighlight @highlightColor
        , scheduledTimeout

    play: (sound) =>
      return unless @soundEnabled or sound[@soundFormat]

      log "Playing sound #{@getUrlForClient() + sound[@soundFormat]}"

      # TODO: Recycle finished audio objects: $(music).bind("ended", function(){ ... });
      audio = new Audio()
      audio.src = @getUrlForClient() + sound[@soundFormat]
      audio.play()

      $(audio).bind 'ended', ->
        $(@).remove()

    login: (username, password) =>
      @loggedIn = false

      if username and password
        # TODO: Try to authenticate with server
        # $.getJSON $.some.loginPath,
        #     username: username
        #     password: password
        #   (data) =>
        #     @loggedIn = data.success?
        @loggedIn = true

        @username = username
        @password = password

      if @loggedIn
        @feedback 'You are now logged in!'
      else
        @feedback 'Login failed!', 'error'

      @loggedIn

    logout: =>
      @loggedIn = false

      # Reset data and clear data in storage
      @username = ''
      @password = ''
      @listeners = []
      @storeData()

      @feedback 'You are now logged out!'

      true

    register: (username, password) =>
      # TODO: Try to authenticate with server
      # $.getJSON $.some.registerPath,
      #     username: username
      #     password: password
      #   (data) =>
      #     true
      true

    createEvent: (subject='', category='', action='', label='') =>
      log 'Sending event creation request'

      # Send event creation request to server
      $.getJSON getUrlForPath(@createEventPath, true),
          username: @username
          password: @password
          subject: subject
          category: category
          action: action
          label: label
          source: @sourceId
        , (data) =>
          @feedback 'Your event has been created!'

      true

    getEventsForListener: (listener) =>
      log "Requesting events for listener #{listener.name}"

      requestData =
        subject: listener.subject
        category: listener.category
        action: listener.action
        label: listener.label
        start: @getCurrentTime() - @pollingInterval - @serverTimedelta

      if @requireLogin
        requestData.username = @username
        requestData.password = @password

      if @useLastKeyOnRequests
        requestData.lastkey = listener.lastkey

      $.getJSON @getUrlForPath(@getEventsPath, true), requestData, (data) =>
        return unless data

        lastEventTimestamp = 0
        timeoutOffset = @serverTimedelta + @pollingInterval - @getCurrentTime()

        for event in data
          log "Received event #{event.key} for listener #{listener.name}"

          # Store last received key
          listener.lastkey = event.key

          # Fire the listener at the correct time
          if Math.abs(event.when - lastEventTimestamp) > @minEventSchedulingDistance
            lastEventTimestamp = event.when

            # Compute the new time delta the listeners callback should be fired
            scheduledTimeout = event.when + timeoutOffset

            # Drop events in the past
            if scheduledTimeout > 0
              log "Scheduling event #{event.key} for listener #{listener.name}"
              listener.callback listener, scheduledTimeout, event
            else
              log "Dropped event #{event.key} from the past at delta #{scheduledTimeout}"
          else
            log "Dropped event #{event.key} which repeated to fast"

    getEvents: =>
      @getEventsForListener listener for listener in @listeners

    requestServerTime: () =>
      # Request the current server time
      requestTime = @getCurrentTime()
      $.getJSON @getUrlForPath(@getServerTime, true), (data) =>
        responseTime = @getCurrentTime()
        if data
          servertime = parseInt data
          if servertime
            @serverTimedelta = Math.round((responseTime + requestTime) / 2 - servertime)
            log "Using time delta #{@serverTimedelta}"
      .error ->
        log "Failed getting time from server, using local time"
        @serverTimedelta = 0

    removeListener: (id) =>
      log "Removing listener with #{id}"
      for idx in [0..@listeners.length - 1] when @listeners[idx].id is id
        @listeners.splice(idx, 1)

      @storeData()
      @updateListenerList @listeners

    registerListener: (name, callback=@scheduleSound, sound='', subject='', category='', action='', label='') =>
      # Check if new listener has a sound and at least one param
      if name and callback and (subject or category or action or label)
        @feedback "Your listener with name '#{name}', sound '#{sound}', category '#{category}', action '#{action}' and label '#{label}' has been registered!"
        newListener =
          id: @guidGenerator()
          name: name
          callback: callback or @scheduleSound
          sound: sound
          subject: subject?.toLowerCase()
          category: category?.toLowerCase()
          action: action?.toLowerCase()
          label: label?.toLowerCase()

        # Store listener in class
        @listeners.push newListener

        # Store listener in local storage when possible
        @storeData()

        # Update listener list in frontend
        @updateListenerList @listeners
      else
        unless callback
          @feedback 'Your listener requires a name and a callback!', 'error'
        unless subject or category or action or label
          @feedback 'Your listener requires a subject, category, action or label!', 'error'

)(jQuery)
