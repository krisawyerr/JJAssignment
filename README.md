# Jelly Jelly Assignment

### Step One: Setting up the server for scaraping the videos and metadata
First, I wanted to create a server that fetches the videos and their metadata. I settled on using an Express server hosted on fly.io for simplicity. I usually use TypeScript, but since it's just one endpoint, I used JavaScript. 

On the site, I saw in the Network tab that it was making a GET request to /shareable_data, and it was returning 200 videos along with their metadata, which is exactly what I need. All the server does is load the page, wait for that specific response, and then pass it through.
# JellyJellyAssignment
