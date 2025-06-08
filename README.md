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

Finally, for the Library tab, it begins with a grid view displaying thumbnails of the saved videos. To play a video inline, use simply long press on a thumbnail. Tapping the thumbnail opens the video in full screen, allowing the user to scroll through it just like on the main feed.

### Step Three: Working on UI
The first part of the work focused on the tab bar and overall layout. I wanted to keep the design simple and natural, in line with the ethos of the app, while making sure every element felt intentional. I decided to use Lottie animations for the tab icons and other UI icons to bring a sense of liveliness. Initially, I tried integrating them directly into the tab bar, but due to animation lag, I opted for using overlays instead. I usually prefer videos to take up the entire screen, but I really liked how the Jelly Jelly apps record screen was in a more contained format. I decided to replicate that feel for both the record and feed screens. For the visual theme, I enforced dark mode beacuse it just felt more calming. I chose a light blue as the primary color and paired it with a dark gray background that isn’t so dark it becomes flat or unnoticeable.

Next, I moved on to the scrolling UI. My goal was to make it reusable for both the feed which pulls data from an API and the library which pulls from CoreData. I implemented a vertical scrolling experience similar to most video apps, where users can swipe to see the next video. Initially, the feed took around 42 seconds for the first video to start playing due to all videos being loaded at once which was clearly unacceptable. Switching to lazy loading dropped that load time to about a second. As for functionality, I replaced the double tap to mute with a visible mute lottie, since the original gesture felt too hidden. I wanted videos to appear clean and distraction free, so the only overlays are the mute button and the timeline, which appears when the video is paused. I also added a mute manager to ensure that videos remain muted consistently across the app, no matter where you are.

For the Create tab, I wanted to keep things as minimal yet impactful as the Home screen. Since the record button would be the only main element on the screen, I wanted to make it unique. I made a jellyfish icon to be the record button and visual timer. As time runs out, the jellyfish icon gradually fills up until the recording ends. To handle the transition after recording, I added a fullscreen blocking overlay that appears once the video is finished and stays until it's formatted and saved. It not really ideal for production, but this helped maintain a smooth flow for redirecting the user to the Library page for this project.

The Library page was straightforward. I displayed the videos in a three column grid, similar to most short form content platforms. The fullscreen view in the Library used the same components from the Home feed, so no changes were needed.

Wrapping things up, I made the loading screen reusable and added the logo I created to it. I wanted the screen to shift from lighter to darker to act as a loading indicator. It also gave the feel that the screen was breathing, making it feel more alive. I went to the JellyJelly site and saw they were using the Ranchers font, so I grabbed it from Google Fonts and added it to my app to use in the loader and the library tab. I also added haptic feedback to make the phone lightly buzz when tapping the tab bar icons or the mute button.

### Step Four: Final Touches
I wanted to go back and fix a few small issues. I cleaned up the code and resolved all the errors. Then I created a simple launch screen to greet the user and help mask some of the waiting time for network calls. I also designed an app icon and connected it to the app. Finally, I went back to the CameraController and made it delete the temporary files like the original front and back camera videos so that only the final video is saved. Now I’m going to upload the app to TestFlight and wrap up the project.

### Extra Change
I wasn’t sure if the app would be uploaded to TestFlight on time, so I decided to keep working on it and add more features.

The first big thing I wanted to add was the ability to like videos. Basically, users can double tap or press the like button to save a shareable item to Core Data and then watch their liked videos in the Library alongside their personal ones. I implemented a few simple rules:

- Like a video when it’s double tapped or the like button is pressed
- Only allow unliking by pressing the like button (not double tapping)
- Personal videos can’t be liked
- Unliking is only allowed from the liked videos section

I reused most of the layout from the personal videos section for this feature.