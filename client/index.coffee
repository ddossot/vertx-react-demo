Rx = require('rxjs')
pkg = require('./package.json')

React = require('react')
R = React.DOM

# TODO
# - wire up websocket to vert.x
# - consume David's event stream
# - use Rx to throttle it and do rollups
# - chart it

# see
# http://neugierig.org/software/blog/2014/02/react-jsx-coffeescript.html
# for notes on using React directly in coffeescript rather than via jsx
component = R.h1 null,
  pkg.name
  " a work in progress brought to you by Tavis and David!"
React.renderComponent(component, document.body);
