Rx = require('rxjs')
pkg = require('./package.json')

React = require('react')
R = React.DOM

component = R.h1 null,
  pkg.name
  " brought to you by Tavis and David!"
React.renderComponent(component, document.body);
