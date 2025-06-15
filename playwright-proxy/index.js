const express = require('express');
const { chromium } = require('playwright');
const { performance } = require('perf_hooks');

const app = express();
const PORT = process.env.PORT || 3000;

const targetPageUrl = 'https://www.jellyjelly.com/feed';
const fetchUrlPrefix = 'https://cbtzdoasmkbbiwnyoxvz.supabase.co/rest/v1/shareable_data';

let cachedResponse = null;
let isUpdatingCache = false;

process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

async function updateCache() {
  if (isUpdatingCache) {
    console.log('Cache update already in progress, skipping...');
    return;
  }

  isUpdatingCache = true;
  const browser = await chromium.launch({ 
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
    timeout: 30000
  });
  const context = await browser.newContext();
  const page = await context.newPage();

  let responseData = null;

  try {
    page.on('requestfinished', async (request) => {
      const url = request.url();
      if (url.startsWith(fetchUrlPrefix)) {
        try {
          const response = await request.response();
          if (response) {
            responseData = await response.json();
          }
        } catch (err) {
          console.error('Error parsing fetch response JSON:', err);
        }
      }
    });

    await page.goto(targetPageUrl, {
      waitUntil: 'domcontentloaded',
      timeout: 60000,
    });

    await page.waitForTimeout(3000);

    if (responseData) {
      cachedResponse = responseData;
      console.log('Cache updated successfully');
    } else {
      console.error('Failed to fetch data for cache update');
    }
  } catch (err) {
    console.error('Error in cache update:', err);
  } finally {
    await browser.close();
    isUpdatingCache = false;
  }
}

updateCache().catch(err => {
  console.error('Error in initial cache update:', err);
});

setInterval(() => {
  updateCache().catch(err => {
    console.error('Error in scheduled cache update:', err);
  });
}, 30000);

app.get('/data', async (req, res) => {
  const startTime = performance.now();
  if (cachedResponse) {
    res.setHeader('Cache-Control', 'no-store');
    const requestDuration = performance.now() - startTime;
    console.log(`Cache hit time: ${requestDuration.toFixed(2)} ms`);  
    return res.json(cachedResponse);
  } else {
    const browser = await chromium.launch({ args: ['--no-sandbox'] });
    const context = await browser.newContext();
    const page = await context.newPage();

    let responseData = null;

    try {
      page.on('requestfinished', async (request) => {
        const url = request.url();
        if (url.startsWith(fetchUrlPrefix)) {
          try {
            const response = await request.response();
            if (response) {
              responseData = await response.json();
              const requestDuration = performance.now() - startTime;
              console.log(`Network request time: ${requestDuration.toFixed(2)} ms`);
            }
          } catch (err) {
            console.error('Error parsing fetch response JSON:', err);
          }
        }
      });

      await page.goto(targetPageUrl, {
        waitUntil: 'domcontentloaded',
        timeout: 60000,
      });

      await page.waitForTimeout(3000);

      if (responseData) {
        cachedResponse = responseData;
        res.setHeader('Cache-Control', 'no-store');
        res.json(cachedResponse)
      } else {
        return res.status(500).json({ error: 'Failed to fetch data' });
      }
    } catch (err) {
      console.error('Error in on-demand fetch:', err);
      return res.status(500).json({ error: err.message });
    } finally {
      await browser.close();
    }
  }
});

const server = app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  updateCache().catch(err => {
    console.error('Error in server startup:', err);
  });
});