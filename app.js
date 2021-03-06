require('coffee-script');
require('jquery');

console.log("Running Maxwell in environment: " + process.argv[2])
process.env[ process.argv[2] ] = true

Circuit = require('./core/circuit');
CircuitElement = require('./component/circuitElement');
Settings = require('./settings/Settings');


// If we are in development environment include all modules:
if(process.env.development)
  c = new Circuit()
  CircuitElement = require('./component/circuitElement');
  ce = new CircuitElement()