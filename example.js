var touchid = require('.')

console.log(touchid.canAuthenticate())
touchid.authenticate('testing macos-touchid', console.log)
