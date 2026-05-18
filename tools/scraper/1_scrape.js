const axios = require('axios');
const cheerio = require('cheerio');
const fs = require('fs');
const path = require('path');

const SUBJECT = 'mathematics';
const START_YEAR = 1990;
const END_YEAR = 2024;
const DELAY_MS = 1200;

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function fetchPage(year, page) {
  const url = `https://myschool.ng/classroom/${SUBJECT}?exam_type=waec&exam_year=${year}&type=obj&page=${page}`;
  const { data } = await axios.get(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
    timeout: 15000
  });
  return data;
}

function parseQuestions(html, year) {
  const $ = cheerio.load(html);
  const questions = [];

  $('.question-item').each((i, el) => {
    const qEl = $(el);

    // Question text — from .question-desc, preserve LaTeX as-is
    const text = qEl.find('.question-desc').text().trim();
    if (!text) return;

    // Options — strip the "A." letter prefix, keep just the content
    const options = [];
    qEl.find('ul.list-unstyled li').each((j, liEl) => {
      const li = $(liEl);
      li.find('strong').remove(); // remove the "A." label
      const optText = li.text().trim();
      if (optText) options.push(optText);
    });

    if (options.length < 2) return;

    questions.push({
      text,
      options,
      correctIndex: null,  // to be filled later
      explanation: '',
      year,
      subject: SUBJECT,
      source: 'waec',
      topicName: null,
      unitName: null,
    });
  });

  return questions;
}

async function scrapeYear(year) {
  const allQuestions = [];
  let page = 1;

  while (true) {
    try {
      const html = await fetchPage(year, page);
      const questions = parseQuestions(html, year);

      if (questions.length === 0) break;

      allQuestions.push(...questions);
      process.stdout.write(`  ${year} p${page}: ${questions.length} questions\n`);
      page++;
      await sleep(DELAY_MS);
    } catch (err) {
      console.error(`  Error on ${year} page ${page}: ${err.message}`);
      break;
    }
  }

  return allQuestions;
}

async function main() {
  const allQuestions = [];

  for (let year = START_YEAR; year <= END_YEAR; year++) {
    const questions = await scrapeYear(year);
    allQuestions.push(...questions);
    console.log(`  → ${year} total: ${questions.length}`);
    await sleep(DELAY_MS);
  }

  const outPath = path.join(__dirname, 'data', 'raw.json');
  fs.writeFileSync(outPath, JSON.stringify({ questions: allQuestions }, null, 2));
  console.log(`\nDone. ${allQuestions.length} total questions saved to data/raw.json`);
}

main().catch(console.error);