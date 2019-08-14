# AICamera
Demonstration of using Pytorch inside an iOS application.

## Read before running the demo

Since Pytorch is not in its final stage, the static libraries generated via cmake haven't been fully optimized yet and thus can't be used in production. This demo is just a proof of concept, aimed at showing that Pytorch can be compiled and run on iOS.

For the demo purpose, the `libtorch.a` only supports one architecture - `arm64`, meaning the code can be only run on an arm64 device. And because of the size issues, the bitcode in `libtorch.a` has been stripped out, so the `enable bitcode` switch in XCode should be turned off as well. Other than that, you're ready to go.

## ScreenShot

<img src="./aicamera.gif" width="400">

