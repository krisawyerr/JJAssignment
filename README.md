# Jelly Jelly Assignment

### Step One: Setting up the server for scraping the videos and metadata
First, I wanted to create a server that fetches the videos and their metadata. I settled on using an Express server hosted on fly.io for simplicity. I usually use TypeScript, but since it's just one endpoint, I used JavaScript. 

On the site, I saw in the Network tab that it was making a GET request to /shareable_data, and it was returning 200 videos along with their metadata, which is exactly what I need. All the server does is load the page, wait for that specific response, and then pass it through.

Hostname: https://playwright-proxy.fly.dev

### Step Two: Setting up the swiftui app and fetching videos from server
To start things off, I set up the MVVM structure and created the tabs for the feed, recording, and library. Then I set up the network request to fetch data from the server. After doing that, I realized the process of scraping the JellyJelly site and then sending the videos and metadata was taking a while (around 15 seconds) which isn’t ideal for a production-level app. But since this is a prototype and scraping isn’t typically used in production environments, I just created a loading screen. I might also consider keeping the Fly.io instance running 24/7 to ensure we always get a hot load, which would reduce the delay.