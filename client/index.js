/** @jsx React.DOM */
var React = require('react');
var Rx = require('rxjs');
var pkg = require('./package.json');

React.renderComponent(<h1>{pkg.name}, brought to you by React!</h1>, document.body);
