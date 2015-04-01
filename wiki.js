var page = require('webpage').create();
page.open('http://en.wikipedia.org/wiki/Sunny', function() {

    phantom.exit();
});