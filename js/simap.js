

(function($) {

  $(function() {
    var smallimap,
        metricsClient,
        debugMode = true,
        serverUrl = 'http://www.small-improvements.com';//'http://localhost:8080'

    function log(message) {
      if (window.console && $.some.debug)
        window.console.log(message);
    }

    // Callback for activity listeners
    function drawEventOnMap(listener, scheduledTimeout, event) {
      log("Scheduling activity on the map for listener " + listener.name + " in " + scheduledTimeout + " ms");

      var eventColor,
          eventWeight = 1,
          eventRadius = 4;
          eventDuration = 2500;

      switch (event.category) {
        case 'appraisal':
          eventColor = '#84d53c'; // Yellow/Green
          break;
        case 'feedback':
          eventColor = '#03f7f4'; // Turqoise
          break;
        case 'objective':
          eventColor = '#31577e'; // Blue
          break;
        case 'admin':
          eventColor = '#ff9c00'; // Orange
          break;
        default:
          eventColor = '#ff00ff'; // Pink
      }

      window.setTimeout(function() {
        log("Enqueing event on the map: " + event.label);

        var newEvent = new $.si.smallimap.events.BlipEvent(smallimap, {
          latitude: event.latitude,
          longitude: event.longitude,
          color: eventColor,
          weight: eventWeight,
          duration: eventDuration,
          radius: eventRadius
        });
        smallimap.enqueueEvent(newEvent);

        metricsClient.play(listener.sound);
      }, scheduledTimeout);
    }

    // Query clients from the server and show them on the map
    function getClientsForMap() {
      $.getJSON(serverUrl + '/queryClientsJSON?callback=?', function(data) {
        log("Queried clients from SI");
        var idx = 0, client;
        for (; idx < data.length; idx++) {
          client = data[idx];
          log("Adding icon for " + client);
          smallimap.addMapIcon(client.name, client.quote, 'img/marker.png', 'img/si.png', client.longitude, client.latitude);
        }

        // Test icons
        smallimap.addMapIcon('Sample Company 1', 'Our completion rate went from 65% to 90% instantly', 'img/marker.png', 'img/disqus.png', -68, -32);
        smallimap.addMapIcon('Sample Company 2', 'Most bestest company ever, I swear!', 'img/marker.png', 'img/quiksilver.png', 32, -27);
        smallimap.addMapIcon('Sample Company 3', 'I love it!', 'img/marker.png', 'img/redballoon.png', 82, 42);
      });
    }

    // Test function for the map which creates random events all over the world
    var testIntervalId = -1;
    window.runSmallimapTest = function() {
      var lastX = 0, lastY = 0,
        pxToX = function (px) { return Math.floor(px/smallimap.dotDiameter); },
        pyToY = function (py) { return Math.floor(py/smallimap.dotDiameter); };

      /*$('#smallimap').mousemove(function (event) {
        var px = event.pageX - $(this).offset().left,// - smallimap.width,
          py = event.pageY - $(this).offset().top,
          x = pxToX(px),
          y = pyToY(py);

        if(x != lastX || y != lastY) {
          var inEvent = new $.si.smallimap.events.LensEvent(smallimap, {
              longitude: smallimap.xToLong(x),
              latitude: smallimap.yToLat(y),
              eventRadius: 0,
              duration: 128,
              fade: "in"
          });
          smallimap.enqueueEvent(inEvent);
          var outEvent = new $.si.smallimap.events.LensEvent(smallimap, {
              longitude: smallimap.xToLong(lastX),
              latitude: smallimap.yToLat(lastY),
              eventRadius: 0,
              delay: 128,
              duration: 256,
              fade: "out"
          });
          smallimap.enqueueEvent(outEvent);
          lastX = x
          lastY = y
        }
      });*/

      testIntervalId = setInterval(function() {
        var event = new $.si.smallimap.events.BlipEvent(smallimap, {
          latitude: Math.random() * 180 - 90,
          longitude: Math.random() * 360 - 180,
          color: '#ff00ff',
            eventRadius: 4,
            duration: 2048,
            weight: 0.5
        });
        smallimap.enqueueEvent(event);
      }, 512);
    };
    window.stopSmallimapTest = function() {
      clearInterval(testIntervalId);
    };

    // Configure metrics client
    $.some.debug = debugMode;
    metricsClient = new $.some.SonicMetricsClient('SIMetricsClient', {
      serverUrl: serverUrl,
      sourceId: 'SIMetricsClient',
      getEventsPath: 'queryActivitiesJSON',
      getServerTime: 'queryServertimeJSON',
      soundEnabled: true,
      useLocalStorage: false,
      useLastKeyOnRequests: false
    });

    // Init map
    smallimap = $('#smallimap').smallimap({
      dotRadius: 4,
      width: 990,
      height: 495
    }).data('api');
    smallimap.run();
    // window.smallimap = smallimap;

    // registerListener: (name, callback, sound='', subject='', category='', action='', label='')
    metricsClient.registerListener('activities', drawEventOnMap, { name: 'plop', mp3: 'sounds/plop.mp3', ogg: 'sounds/plop.ogg' }, 'siactivity');

    // Init metrics client
    metricsClient.init().run();

    // Get clients and draw them on the map
    getClientsForMap();

  });

})(jQuery);
