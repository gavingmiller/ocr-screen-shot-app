# OCR Screenshot App (iOS)

This project is pure vibe coding an iOS App on OpenAI Codex. Minimal programming done by me directly aside from some XCode debugging.

This sample project demonstrates how to pick screenshots from the photo library, perform OCR on each image, extract game related stats and upload the results to a Google Form. Each screenshot is listed with a success or failure indicator after uploading.

## Features

- Select one or more images using `PhotosPicker`.
- Perform text recognition using the Vision framework.
- Parse recognized text for the following fields:
  - **tier**
  - **wave**
  - **real time (duration)**
  - **coins earned**
  - **cells earned**
  - **reroll shards earned**
- Send extracted values to the provided Google Form.
- Display a list of processed screenshots with an indicator for upload success or failure.
- View extracted stats in a table on the detail screen.

## Setup

1. Open the `OCRScreenShotApp` folder in Xcode.
2. Replace the placeholder entry IDs in `GoogleFormPoster.swift` with the actual field entry IDs from your Google Form.
3. Build and run on an iOS device running iOS 16 or later.

This repository now includes an `OCRScreenShotApp.xcodeproj` file. Open this project in Xcode to build and run the app.

## Input

![example](https://github.com/gavingmiller/ocr-screen-shot-app/blob/main/OCRScreenShotApp/OCRScreenShotApp/example.png)

## Output

<img width="350" alt="image" src="https://github.com/user-attachments/assets/60a3c0f3-b51d-43c7-9875-0933d7eeb65f" />

