import fetch from "node-fetch";
import { CookieJar } from "tough-cookie";
import fetchCookie from "fetch-cookie";
import * as cheerio from "cheerio";
import OpenAI from "openai";
import { GoogleGenAI } from "@google/genai";
// import { config } from "dotenv";

// config();

const WP = "https://kojinjigyou.org";
const USER = "azarasikazuki@gmail.com";
const PASS = "sealsoft2022";
const OPNEAI_API_KEY = "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"

const jar = new CookieJar();
const client = fetchCookie(fetch, jar);
const openai = new OpenAI({ apiKey: OPNEAI_API_KEY });

// TODO: reidirectいらないかもしれない。



const ai = new GoogleGenAI({apiKey: "AIzaSyDWegBxvh0MF5vd7IY4XvoNM53knGdxtyg"});

async function main() {
  const response = await ai.models.generateContent({
    model: "gemini-3-flash-preview",
    contents: "Explain how AI works in a few words",
  });
  console.log(response.text);
}

await main();


// ──────────────────────────────────
// 1) ログイン
// ──────────────────────────────────
async function login() {
  // リダイレクト先の取得、失敗したら例外
  const loginPage = await client(`${WP}/wp-login.php`);
  const html = await loginPage.text();
  const $ = cheerio.load(html);
  const redirect = $('input[name="redirect_to"]').val();
  if (!redirect) throw new Error("redirect_to が取得できませんでした");

  // ログインリクエスト
  const res = await client(`${WP}/wp-login.php`, {
    method: "POST",
    redirect: "manual",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      log: USER,
      pwd: PASS,
      redirect_to: redirect,
      // WordPressのログインフォームには、Cookieが有効かどうかを確認するためのtestcookieというフィールドがあるため、それも送る
      // 確認したらマジであった。AIすげぇ
      testcookie: "1"
    })
  });

  // 302ならログイン成功（Cookieはjarに自動保存済み）
  if (res.status === 302) {
    console.log("✅ ログイン成功");
    return;
  }

  // エラー時は login_errorというidの要素が画面に表示されるため、それで判定をする
  const body = await res.text();
  if (body.includes("login_error")) {
    const $body = cheerio.load(body);
    const error = $body("#login_error").text().trim();
    throw new Error(`ログイン失敗: ${error}`);
  }

  throw new Error(`ログイン失敗: 予期しないステータス ${res.status}`);
}

// ──────────────────────────────────
// 2) nonce取得
// ──────────────────────────────────
async function getNonce() {
  const admin = await client(`${WP}/wp-admin/post-new.php`);
  const html = await admin.text();

  const match =
    html.match(/wpApiSettings\s*=\s*\{[^}]*"nonce"\s*:\s*"([a-f0-9]+)"/) ||
    html.match(/"nonce"\s*:\s*"([a-f0-9]+)"/) ||
    html.match(/name="_wpnonce"\s+value="([^"]+)"/) ||
    html.match(/name="_wpnonce"[^>]*value="([^"]+)"/) ||
    html.match(/value="([^"]+)"[^>]*name="_wpnonce"/);

  if (!match) throw new Error("nonce取得失敗");

  console.log("✅ nonce取得成功");
  return match[1];
}

// ──────────────────────────────────
// 3) Geminiで記事を生成
// ──────────────────────────────────
async function generateArticle(topic) {
  console.log(`📝 記事を生成中... テーマ: 「${topic}」`);

  const prompt = `
あなたはプロのブログライターです。
以下のルールに従って記事を作成してください：
- タイトルと本文をJSON形式で返す
- 本文はHTMLタグ（<h2>, <h3>, <p>, <ul>, <li> 等）を使って構造化する
- 1500〜2500文字程度の記事にする
- SEOを意識した自然な文章にする
- レスポンスは以下のJSON形式のみ返す:
{"title": "記事タイトル", "content": "<h2>見出し</h2><p>本文...</p>"}
テーマ: ${topic}
`;

  const response = await ai.models.generateContent({
    model: "gemini-3-flash-preview",
    contents: prompt,
  });

  // Geminiはtextで返すのでパース
  let article;
  try {
    article = JSON.parse(response.text);
  } catch (e) {
    console.error("❌ Geminiレスポンスのパース失敗:", response.text);
    throw e;
  }
  console.log(`✅ 記事生成完了: 「${article.title}」`);
  return article;
}

/**
 * 3) 投稿
 */
async function createPost(nonce) {
  const res = await client(`${WP}/wp-json/wp/v2/posts`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-WP-Nonce": nonce
    },
    body: JSON.stringify({
      title: "APIログイン投稿テスト",
      content: "<p>これはテストです</p>",
      status: "publish"
    })
  });

  const json = await res.json();
  console.log(json);
}

await login();
const nonce = await getNonce();
const article = await generateArticle("CQRS/ESやDDDについて初心者向けに解説");
// await createPost(nonce);