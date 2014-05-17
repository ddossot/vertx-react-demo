# common js / browserify imports
pkg = require('./package.json')
_ = require('lodash')
React = require('react')
R = React.DOM
Rx = require('rx')
{Observable, Observer, Subject} = Rx

################################################################################
# utils
log = console.log.bind(console)
logWith = (label) ->
  (args...) -> console.log.apply(console, [label].concat(args))

stackTrace = () -> new Error().stack

################################################################################
# Rx utils

logAllObserver = (label) ->
  Observer.create(
    logWith(label + ' - Value:'),
    logWith(label + ' - Error:'),
    logWith(label + ' - Completed'))

observeWebSocket = (url) ->
  # or just use
  # https://github.com/Reactive-Extensions/RxJS-DOM/tree/master/doc#rxdomfromwebsocketurl-protocol-observeroronnext
  # I'm including this as an example of how to create a bidirectional subject
  ws = new WebSocket(url)
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

################################################################################
# application root

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
    # Rx.Subjects to decouple UI from event sources
    # Think of these as the ports on a switchboard
    # http://makemusicals.com/wp-content/uploads/2011/11/switchboard1.jpg
    # They are a layer of indirection between the source of events and the consumers.
    timer: new Subject()
    timerSwitch: new Subject()
    mouseDrags: new Subject()
    requests: new Subject()
    responseTimes: new Subject()
  demos: {}
  uiRoot: null

demos = app.demos

################################################################################
# consume mod_metrics data from David's vert.x app over websockets:
wsurl = (path) ->
  host = document.location.hostname
  wsport = "8080" #document.location.port
  "ws://#{host}:#{wsport}#{path}"

demos.metricsWebsockets = (config, eventSubjects) ->
  url = (endpoint_name) ->
    url0 = config.wsAPI[endpoint_name]
    if url0[0] == "/"
      wsurl(url0)
    else
      url0
  #TODO add reconnector, plus manage subscriptions
  observeWebSocket(url("requests"))
    .sample(500)
    .map((ev) -> JSON.parse(ev.data))
    .map((d) ->
      d = _.mapValues(d, (v) -> v.toFixed(2))
      d.count = Math.round(d.count)
      d)
    .subscribe((e) -> eventSubjects.requests.onNext(e))

  observeWebSocket(url("responseTimes"))
    .sample(500)
    .subscribe((e) -> eventSubjects.responseTimes.onNext(e))

################################################################################
# additional Observable event sources demos included in presentation

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

mouseDragResetEv =
  startpos: {x: 0, y: 0}
  target: ''
  dx: 0
  dy: 0

demos.mouseDrags = (eventSubjects) ->
  dragsSource = mouseDrags(document)
  dragsSource.subscribe (drag) -> eventSubjects.mouseDrags.onNext(drag)
  dragsSource.subscribe(logAllObserver('drags'))
  mouseUp.subscribe () -> eventSubjects.mouseDrags.onNext(mouseDragResetEv)

demos.timer = (eventSubjects) ->
  ticks = Observable
    .interval(1000) # ms
    .timeInterval()
    .pausable(eventSubjects.timerSwitch)
    .pluck("value")
  ticks.subscribe((tick) -> eventSubjects.timer.onNext(tick))
  ticks.subscribe(logAllObserver('timer'))

################################################################################
# additional misc Observable demos

demos.toAsync = () ->
  f = (arg) ->
    "async: #{arg} #{stackTrace()}"
  fasync = Observable.toAsync(f)
  Observable.interval(1000).flatMap(fasync).subscribe(log)

demos.replay = () ->
  sub = new Rx.ReplaySubject()
  # ReplaySubject args: bufferSize, windowSize, scheduler
  sub.onNext(2)
  sub.onNext(3)
  sub.subscribe(logAllObserver('replay'))
  sub.onNext(4)
  sub.onCompleted()
  sub.onNext(5)

demos.behaviours = () ->
  sub = new Rx.BehaviorSubject(42)
  # same as `sub = new Rx.ReplaySubject(1); sub.onNext(42)`
  sub.onNext(2)
  sub.onNext(3)
  sub.subscribe(logAllObserver('behaviours'))
  sub.onNext(4)
  sub.onCompleted()

demos.backpressure = () ->
  source = Observable.range(0, 10).timeInterval().controlled()
  source.subscribe(logAllObserver("controlled"))
  source.request(4)
  source.request(4)
  sub.onCompleted()
  source.request(4)

################################################################################
# Demo UI using React.js
#

# a mixin to handle Rx <-> React boilerplate
ReactRxMixin =
  componentWillMount: ->
    @subscriptions = []
  componentWillUnmount: ->
    # this is not essential in this demo, but keep cleanup of
    # subscriptions in mind
    log("unmounting and cleaning up subscriptions: ", @)
    @subscriptions.forEach((sub) -> sub.dispose())
  manageSubcription: (sub) ->
    @subscriptions.push(sub)
  observeDom: (domEvent, observer) ->
    # see http://blog.ankl.am/rx-101-event-delegation/ for more sophisticated approaches
    @manageSubcription(Observable.fromEvent(@getDOMNode(), domEvent).subscribe(observer))

RequestsWidget = React.createClass
  mixins: [ReactRxMixin]
  componentWillMount: ->
    @manageSubcription(@props.events.subscribe(@setState.bind(@)))
  getInitialState: ->
    '1m':  '-'
    '5m':  '-'
    '15m': '-'
    count: '-'
    mean:  '-'
  render: ->
    R.div {},
      (R.h2 {}, "Vert.x Request Metrics over WebSocket"),
      '1m: ' + @state['1m'],
      R.br {},
      '5m: ' + @state['5m'],
      R.br {},
      '15m: ' + @state['15m'],
      R.br {},
      'count: ' + @state.count,
      R.br {},
      'mean: ' + @state.mean, '' # trailing space required for some reason

MouseDragWidget = React.createClass
  mixins: [ReactRxMixin]
  getInitialState: -> mouseDragResetEv
  componentWillMount: ->
    @manageSubcription(@props.events.subscribe(@setState.bind(@)))
  render: ->
    R.div {},
      (R.h2 {}, "Mouse Drag Demo"),
      "start pos: #{@state.startpos.x} #{@state.startpos.y}",
      R.br {},
      "target: #{@state.target}",
      R.br {},
      "dx: #{@state.dx}",
      R.br {},
      "dy: #{@state.dy}", ''

TimerWidget = React.createClass
  mixins: [ReactRxMixin]
  getInitialState: ->
    timer: 0
    active: false

  render: ->
    display = if @state.active then @state.timer else 'off'
    R.div {},
       (R.h2 {}, "Pausable Timer Demo"),
       "timer: #{display}", ''

  componentDidMount: ->
    @manageSubcription(@props.events.subscribe((t) => @setState(timer: t)))
    @observeDom('click', (_ev) =>
      @setState(active: !@state.active)
      @props.timerSwitch.onNext(@state.active))

  ## or instead of `observeDom`: {onClick: @handleClick} +
  #handleClick: (ev) ->
    #@setState(active: !@state.active)
    #@props.timerSwitch.onNext(@state.active)

initUI = (eventSubjects) ->
  rootComponent = R.div {},
    RequestsWidget(events: eventSubjects.requests),
    MouseDragWidget(events: eventSubjects.mouseDrags),
    TimerWidget(events: eventSubjects.timer, timerSwitch: eventSubjects.timerSwitch)
  React.renderComponent(rootComponent, document.getElementById('app'))


################################################################################
# start your engines
onload = ->
  app.uiRoot = initUI(app.events)
  # start the related demo event sources
  demos.mouseDrags(app.events)
  demos.timer(app.events)
  demos.metricsWebsockets(app.config, app.events)
  #app.events.responseTimes.subscribe(logAllObserver('responseTimes'))
  log('loaded')

window.addEventListener("load", onload, false)
