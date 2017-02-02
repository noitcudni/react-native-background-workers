# React Native Background Workers

This project was inspired by https://github.com/devfd/react-native-workers.  Since that project has been in a broken state under iOS (I'm not sure about Android), I've decided to write my own.

## Installation
`npm install https://github.com/noitcudni/react-native-background-workers.git --save` <br/>
`rnpm link react-native-background-workers`

## Bundle script
For release build to work, we'll need to bundle up worker javascript files as well. Your worker files should end with `_worker.js` and they need to reside in `App/Workers` relative to your App's root directory.

Shamelessly stolen from https://github.com/devfd/react-native-workers/issues/21.
Add the following to your react native app's Build Phases -> Bundle React Native code and images section:

```
export NODE_BINARY=node
../node_modules/react-native-background-worker/react-native-workers.sh ;; <-- ADD THIS LINE
../node_modules/react-native/packager/react-native-xcode.sh
```
