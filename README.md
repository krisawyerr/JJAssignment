# Jelly Jelly Assignment

### Step One: Setting up the server for scraping the videos and metadata
First, I wanted to create a server that fetches the videos and their metadata. I settled on using an Express server hosted on fly.io for simplicity. I usually use TypeScript, but since it's just one endpoint, I used JavaScript. 

On the site, I saw in the Network tab that it was making a GET request to /shareable_data, and it was returning 200 videos along with their metadata, which is exactly what I need. All the server does is load the page, wait for that specific response, and then pass it through.

Hostname: https://playwright-proxy.fly.dev

### Step Two: Setting up the swiftui app and fetching videos from server
To start things off, I set up the MVVM structure and created the tabs for the feed, recording, and library. Then I set up the network request to fetch data from the server. After doing that, I realized the process of scraping the JellyJelly site and then sending the videos and metadata was taking a while (around 15 seconds) which isn’t ideal for a production-level app. But since this is a prototype and scraping isn’t typically used in production environments, I just created a loading screen. I might also consider keeping the Fly.io instance running 24/7 to ensure we always get a hot load, which would reduce the delay.

### Step Three: Implementing bare minimum functionality
My plan is to get the bare minimum functionality working for the three tabs first, then return later to refine the UI. I started with the Feed tab. It uses an AVPlayer that fills the screen, excluding the tab bar. I’ve added tap and swipe gestures: swiping up goes back to the previous video, swiping down advances to the next one, a single tap toggles mute, and a double tap also toggles mute. When the video is paused, a scrollbar appears to allow scrubbing to a specific part of the video.

For the Create tab, I set up the cameras to display and record for a maximum of 15 seconds. I built functions to crop the video to show only what was visible during recording instead of the full camera frame, merge the front and back camera recordings into a single video, and then added the audio onto the merged result. Currently, I’m saving the front, back, and merged videos to app data, but I might eventually store only the merged video. Once everything is processed, the app saves the video path to Core Data and redirects the user to the Library page. This was my first time working with a dual-camera setup, so if I have more time, I plan to go back and clean things up to make the experience more production-ready.