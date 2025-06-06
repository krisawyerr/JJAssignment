const express = require('express');
const { chromium } = require('playwright');

const app = express();
const PORT = process.env.PORT || 3000;

const targetPageUrl = 'https://www.jellyjelly.com/feed';
const fetchUrlPrefix = 'https://cbtzdoasmkbbiwnyoxvz.supabase.co/rest/v1/shareable_data';

app.get('/data', async (req, res) => {
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
      res.setHeader('Cache-Control', 'no-store');
      return res.json(responseData);
    } else {
      return res.status(500).json({ error: 'Fetch response not found' });
    }
  } catch (err) {
    console.error('Error in handler:', err);
    return res.status(500).json({ error: err.message });
  } finally {
    await browser.close();
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});
