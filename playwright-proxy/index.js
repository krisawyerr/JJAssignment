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

  try {
    let responseData = null;

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

    await page.goto(targetPageUrl, { waitUntil: 'networkidle' });

    await page.waitForTimeout(2000);

    await browser.close();

    if (responseData) {
      return res.json(responseData);
    } else {
      return res.status(500).json({ error: 'Fetch response not found' });
    }

  } catch (err) {
    await browser.close();
    console.error('Error in handler:', err);
    return res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
