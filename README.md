# `macos-touchid`

[![Build Status](https://travis-ci.org/emilbayes/macos-touchid.svg?branch=master)](https://travis-ci.org/emilbayes/macos-touchid)

> Native module for working with macOS Local Authentication (eg. TouchID)

## Usage

```js
var touchid = require('macos-touchid')

if (touchid.canAuthenticate() === false) {
  throw new Error('No authentication method available')
}

touchid.authenticate('authenticate you', function (err, didAuthenticate) {
  if (err) throw err

  console.log(didAuthenticate ? `You're in!` : 'You will be terminated')
})

```

## API

### `const bool = touchid.canAuthenticate()`

Check if authentication is [available](https://developer.apple.com/documentation/localauthentication/lapolicy/lapolicydeviceownerauthentication?language=objc)

### `touchid.authenticate(reason, cb(err, bool))`

Attempt to [authenticate](https://developer.apple.com/documentation/localauthentication/lapolicy/lapolicydeviceownerauthentication?language=objc)

## Install

```sh
npm install macos-touchid
```

## License

[ISC](LICENSE)
