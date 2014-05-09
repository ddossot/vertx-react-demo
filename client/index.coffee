pkg = require('./package.json')
_ = require('lodash')
React = require('react')
R = React.DOM
Rx = require('rx')
#Rxdom = require('rx-dom') # may not need

window.app_root = app_root =
  ns:
    Rx: Rx
    #Rxdom: Rxdom
    React: React
  config:
    pkg: pkg
    rest_api:
      sources: "/api/metrics/sources"
      requests: "/api/metrics/meters/requests"
      responseTimes: "/api/metrics/histograms/responseTimes"
    ws_api:
     requests: "/streams/meters/requests"
     responseTimes: "/streams/metrics/histograms/responseTimes"
  events:
    ui: new Rx.Subject()
    requests: new Rx.Subject()
    responseTimes: new Rx.Subject()
  subscriptions:
    # keep track for disposing them later: off/on
    requests_ws: null
    responseTimes_ws: null
  ui_root: null

wsurl = (path) ->
  host = document.location.hostname
  wsport = "8080" #document.location.port
  "ws://#{host}:#{wsport}#{path}"

observeWebSocket = (url) ->
  # or just use
  # https://github.com/Reactive-Extensions/RxJS-DOM/tree/master/doc#rxdomfromwebsocketurl-protocol-observeroronnext
  # but I'm including this as an example of how to create a bidirectional subject
  if url[0] == "/"
    url = wsurl(url)
  ws = new WebSocket(url)
  observable = Rx.Observable.create (obs) ->
    ws.onmessage = obs.onNext.bind(obs)
    ws.onerror = obs.onError.bind(obs)
    ws.onclose = obs.onCompleted.bind(obs)
    # Return way to unsubscribe
    -> ws.close()
  observer = Rx.Observer.create (data) ->
    if ws.readyState == WebSocket.OPEN
      ws.send(data)
  Rx.Subject.create(observer, observable)

RequestsWidget = React.createClass
  getInitialState: ->
    '1m':  '-'
    '5m':  '-'
    '15m': '-'
    count: '-'
    mean:  '-'

  componentWillMount: ->
    app_root.events.requests.subscribe(@setState.bind(@))

  render: ->
      (R.div {}, [
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
  component = RequestsWidget({})
  app_root.ui_root = React.renderComponent(component, document.body);

connect_metrics_ws_to_sub = (url, sub) ->
  observeWebSocket(url)
    .map((ev) -> JSON.parse(ev.data))
    .map((d) -> _.mapValues(d, (v) -> v.toFixed(2)))
    .subscribe((e) -> sub.onNext(e))

init_websockets = ->
  url = (endpoint_name) -> app_root.config.ws_api[endpoint_name]
  evs = app_root.events
  app_root.subscriptions =
    requests_ws: connect_metrics_ws_to_sub(url("requests"), evs.requests)
    responseTimes_ws: connect_metrics_ws_to_sub(url("responseTimes"), evs.responseTimes)

mouse_move_demo = ->
  Rx.Observable.fromEvent(document, 'mousemove')
    .distinctUntilChanged()
    .sample(250)
    .subscribe (e) ->
      #console.log("mouse : #{e}")
      console.log("mouse x: #{e.clientX} y: #{e.clientX}")

onload = ->
  init_ui()
  mouse_move_demo()
  init_websockets()
  app_root.events.requests
    .sample(3000)
    .subscribe (e) -> console.log(e)

window.addEventListener("load", onload, false)
