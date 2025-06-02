# Tower Analysis (iOS)

This project is pure vibe coding an iOS App on OpenAI Codex. Minimal programming done by me directly aside from some XCode debugging.

This sample project demonstrates how to pick screenshots from the photo library and perform OCR on each image to extract game related stats.

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
- Display the processed screenshots in a grid for quick access.
- A spinner appears on each screenshot while OCR processing is underway and a
  check mark is shown once its stats are saved to the database.
- View extracted stats in a table on the detail screen.
- Save stats locally using the **Add to Analysis Database** button for later review.

## Setup

1. Open the `OCRScreenShotApp` folder in Xcode.
2. Build and run on an iOS device running iOS 16 or later.

This repository now includes an `OCRScreenShotApp.xcodeproj` file. Open this project in Xcode to build and run the app.

## Input

![example](https://github.com/gavingmiller/ocr-screen-shot-app/blob/main/OCRScreenShotApp/OCRScreenShotApp/example.png)

## Output

<img width="350" alt="image" src="https://github.com/user-attachments/assets/60a3c0f3-b51d-43c7-9875-0933d7eeb65f" />

