pkg = require('./package.json')
_ = require('lodash')
React = require('react')
R = React.DOM
Rx = require('rx')
#Rxdom = require('rx-dom') # may not need

log = console.log.bind(console)

{Observable, Observer, Subject} = Rx

window.app = app =
  ns:
    Rx: Rx
    React: React
  config:
    pkg: pkg
    restAPI:
      sources: "/api/metrics/sources"
      requests: "/api/metrics/meters/requests"
      responseTimes: "/api/metrics/histograms/responseTimes"
    wsAPI:
     requests: "/streams/meters/requests"
     responseTimes: "/streams/metrics/histograms/responseTimes"
  events:
    ui: new Subject()
    mouseDemo: new Subject()
    requests: new Subject()
    responseTimes: new Subject()
  subscriptions:
    # keep track for disposing them later: off/on
    requestsWS: null
    responseTimesWS: null
  demos: {}
  uiRoot: null

logWith = (label) ->
  (args...) -> console.log.apply(console, [label].concat(args))

logAllObserver = (label) ->
  Observer.create(
    logWith(label + ' - Value:'),
    logWith(label + ' - Error:'),
    logWith(label + ' - Completed'))

wsurl = (path) ->
  host = document.location.hostname
  wsport = "8080" #document.location.port
  "ws://#{host}:#{wsport}#{path}"

observeWebSocket = (url) ->
  # or just use
  # https://github.com/Reactive-Extensions/RxJS-DOM/tree/master/doc#rxdomfromwebsocketurl-protocol-observeroronnext
  # but I'm including this as an example of how to create a bidirectional subject
  ws = new WebSocket(if url[0] == "/" then wsurl(url) else url)
  observable = Observable.create (obs) ->
    ws.onmessage = obs.onNext.bind(obs)
    ws.onerror = obs.onError.bind(obs)
    ws.onclose = obs.onCompleted.bind(obs)
    # Return way to unsubscribe
    -> ws.close()
  observer = Observer.create (data) ->
    if ws.readyState == WebSocket.OPEN
      ws.send(data)
  Subject.create(observer, observable)

MouseMoveWidget = React.createClass
  getInitialState: ->
    startpos: {x: 0, y: 0}
    dx: 0
    dy: 0
    target: ''
  render: ->
      (R.div {style: {float: "right"}},
        [(R.h2 {}, "Mouse drag demo"),
        "start pos: #{@state.startpos.x} #{@state.startpos.y}",
        R.br {},
        "target: #{@state.target}",
        R.br {},
        "dx: #{@state.dx}",
        R.br {},
        "dy: #{@state.dy}",
        R.br {},
        ])

  componentWillMount: ->
    @subscription = app.events.mouseDemo.subscribe(@setState.bind(@))

  componentWillUnmount: ->
    @subscription.dispose()

RequestsWidget = React.createClass
  getInitialState: ->
    '1m':  '-'
    '5m':  '-'
    '15m': '-'
    count: '-'
    mean:  '-'

  componentWillMount: ->
    @subscription = app.events.requests.subscribe(@setState.bind(@))
  componentWillUnmount: ->
    @subscription.dispose()

  componentDidUpdate: (prevProps, prevState) ->
    null
  componentWillUpdate: (nextProps, nextState) ->
    null

  render: ->
      (R.div {style: {float: "left"}}, [
        (R.h2 {}, "Vert.x Request Metrics"),
        '1m: ' + @state['1m'],
        R.br {},
        '5m: ' + @state['5m'],
        R.br {},
        '15m: ' + @state['15m'],
        R.br {},
        'count: ' + @state.count,
        R.br {},
        'mean: ' + @state.mean,
        R.br {}
        ])

init_ui = ->
  component = R.div {},
    RequestsWidget({}),
    MouseMoveWidget()

  app.uiRoot = React.renderComponent(component, document.getElementById('app'));

connect_metrics_ws_to_sub = (url, sub) ->
  observeWebSocket(url)
    .sample(500)
    .map((ev) -> JSON.parse(ev.data))
    .map((d) ->
      d = _.mapValues(d, (v) -> v.toFixed(2))
      d.count = Math.round(d.count)
      d)
    .subscribe((e) -> sub.onNext(e))

init_websockets = ->
  #TODO add reconnector
  url = (endpoint_name) -> app.config.wsAPI[endpoint_name]
  evs = app.events
  app.subscriptions =
    requestsWS: connect_metrics_ws_to_sub(url("requests"), evs.requests)
    responseTimesWS: connect_metrics_ws_to_sub(url("responseTimes"), evs.responseTimes)

mouseUp = Observable.fromEvent(document, 'mouseup')
mouseMoves = Observable.fromEvent(document, 'mousemove')
mouseDrags = (elem) ->
  Observable.fromEvent(elem, 'mousedown').selectMany (start) ->
    start.preventDefault()
    startpos = {x: start.clientX, y: start.clientY}
    target = start.target
    mouseMoves.takeUntil(mouseUp).select (moveEv) ->
      startpos: startpos
      target: target
      dx: moveEv.clientX - startpos.x
      dy: moveEv.clientY - startpos.y

app.demos.mouseMove = ->
  mouseDrags(document).subscribe (drag) ->
    app.events.mouseDemo.onNext(drag)
  mouseUp.subscribe () ->
    app.events.mouseDemo.onNext(
      startpos: {x: 0, y: 0}
      target: ''
      dx: 0
      dy: 0)

app.demos.timer = () ->
  timerOn = true
  timerSwitch = new Subject()
  Observable
    .interval(500) # ms
    .timeInterval()
    .pausable(timerSwitch)
    .pluck("value")
    .subscribe(log)
  Observable.fromEvent(document, 'click')
    .subscribe ->
      timerOn = !timerOn
      if timerOn
        console.log("timer on")
      else
        console.log("timer off")
      timerSwitch.onNext(timerOn)

stackTrace = () -> new Error().stack
app.demos.toAsync = () ->
  f = (arg) ->
    "async: #{arg} #{stackTrace()}"
  fasync = Observable.toAsync(f)
  Observable.interval(1000).flatMap(fasync).subscribe(log)

app.demos.replay = () ->
  sub = new Rx.ReplaySubject()
  # bufferSize, windowSize, scheduler
  sub.onNext(2)
  sub.onNext(3)
  sub.subscribe(log)
  sub.onNext(4)

app.demos.behaviours = () ->
  sub = new Rx.BehaviorSubject(42)
  # same as `sub = new Rx.ReplaySubject(1); sub.onNext(42)`
  sub.onNext(2)
  sub.onNext(3)
  sub.subscribe(log)
  sub.onNext(4)

app.demos.backpressure = () ->
  source = Observable.range(0, 10).timeInterval().controlled()
  source.subscribe(logWith("controlled:"))
  source.request(4)
  source.request(4)

onload = ->
  init_ui()
  app.demos.mouseMove()
  init_websockets()
  #log("--")
  #app.demos.behaviours()
  #app.demos.replay()
  #app.demos.backpressures()
  #app.demos.timer()
  #app.demos.toAsync()
#
window.addEventListener("load", onload, false)
