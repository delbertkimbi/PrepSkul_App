# Agora Web SDK Download Instructions

The Agora Web SDK file (`iris-web-rtc.js`) needs to be downloaded and placed in this `web` folder.

## Important: Flutter Package Requirements

The `agora_rtc_engine` Flutter package uses `iris_web` for web support, which requires the **iris-web-rtc** script (NOT AgoraRTC_N.js).

## Download Steps

1. Visit the Agora SDK download page: https://docs.agora.io/en/sdks?platform=web
2. Download the **iris-web-rtc** script (for Web SDK v4.x)
3. Save as: `iris-web-rtc.js` in the `web` folder

## Direct Download Link

You can download directly using:
- URL: https://download.agora.io/sdk/release/iris-web-rtc_n450_w4220_0.8.6.js
- Save as: `iris-web-rtc.js` in the `web` folder

## Verification

After downloading, verify the file exists:
- File path: `web/iris-web-rtc.js`
- File should be referenced in `web/index.html` as: `<script src="iris-web-rtc.js"></script>`

## Note

The file is already referenced in `index.html`. Once you download and place the file, the web version will be able to join video sessions.

## Why iris-web-rtc instead of AgoraRTC_N.js?

The Flutter `agora_rtc_engine` package uses the `iris_web` implementation which requires the `iris-web-rtc.js` script. The error "createIrisApiEngine" indicates the package is looking for the iris API, not the AgoraRTC API.

