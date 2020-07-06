'use strict';

var css = require('./style.css');

// Require index.html so it gets copied to dist
require('../index.html');

import { Elm } from "./src/Main.elm";
var mountNode = document.getElementById('main');

var app = Elm.Main.init({ node: mountNode });
