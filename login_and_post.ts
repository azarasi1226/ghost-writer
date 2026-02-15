import fetch, { Response } from "node-fetch";
import { CookieJar } from "tough-cookie";
import fetchCookie from "fetch-cookie";
import * as cheerio from "cheerio";
import { GoogleGenAI } from "@google/genai";
import { config } from "dotenv";
config();

const WP = process.env.WP_URL!;
const USER = process.env.WP_USER!;
const PASS = process.env.WP_PASS!;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY!;
const GEMINI_MODEL = process.env.GEMINI_MODEL!;

const jar = new CookieJar();
const client = fetchCookie(fetch, jar);
const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY });

type Article = {
  title: string;
  content: string;
};

/**
 * WordPressにログインする（リダイレクトで成功判定、エラー時は詳細表示）
 */
async function login(): Promise<void> {
  const loginPage = await client(`${WP}/wp-login.php`);
  const html = await loginPage.text();
  const $ = cheerio.load(html);
  const redirect = $('input[name="redirect_to"]').val();
  if (!redirect) throw new Error("redirect_to が取得できませんでした");

  const res: Response = await client(`${WP}/wp-login.php`, {
    method: "POST",
    redirect: "manual",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      log: USER,
      pwd: PASS,
      redirect_to: redirect as string,
      testcookie: "1"
    })
  });

  if (res.status === 302) {
    console.log("✅ ログイン成功");
    return;
  }

  const body = await res.text();
  if (body.includes("login_error")) {
    const $body = cheerio.load(body);
    const error = $body("#login_error").text().trim();
    throw new Error(`ログイン失敗: ${error}`);
  }

  throw new Error(`ログイン失敗: 予期しないステータス ${res.status}`);
}

/**
 * WordPress管理画面からnonce（API用トークン）を取得する
 */
async function getNonce(): Promise<string> {
  const admin = await client(`${WP}/wp-admin/post-new.php`);
  const html = await admin.text();

  const match =
    html.match(/wpApiSettings\s*=\s*\{[^}]*"nonce"\s*:\s*"([a-f0-9]+)"/);

  if (!match) throw new Error("nonce取得失敗");

  console.log("✅ nonce取得成功");
  return match[1];
}

/**
 * Gemini APIで記事を自動生成する（JSON形式でタイトル・本文を取得）
 */
async function generateArticle(): Promise<Article> {
  console.log(`📝 記事を生成中...`);

  const prompt = `
あなたはプロのブログライターです。
以下のルールに従って記事を作成してください

- テーマはコンピューターサイエンス、プログラムミング、ソフトウェアアーキテクチャなどIT技術系全般とし、完全にランダムに選んでください
- タイトルと本文をJSON形式で返す
- 本文はHTMLタグ（<h2>, <h3>, <p>, <ul>, <li> 等）を使って構造化する
- 500文字程度の記事にする
- SEOを意識した自然な文章にする
- レスポンスはこのJSON構造にて返す。 {"title": "記事タイトル", "content": "記事本文"}
- コードブロックは使わないでください。純粋なJSONテキストのみを返してください。そのままJSONとしてパースし、後続の処理で使うためです。
`;
  const response = await ai.models.generateContent({
    model: GEMINI_MODEL,
    contents: prompt,
  });

   // コードブロック除去
  let text = response.text?.trim() ?? "";
  if (text.startsWith("```")) {
    text = text.replace(/^```json\s*/i, "").replace(/^```/, "").replace(/```$/, "").trim();
  }


  try {
    let article: Article = JSON.parse(text);
    console.log(`✅ 記事生成完了: 「${article.title}」`);
    return article;
  } catch (e) {
    console.error("❌ Geminiレスポンスのパース失敗:", text);
    throw e;
  }
}

/**
 * 生成した記事をWordPress REST APIで投稿する
 */
async function createPost(nonce: string, article: Article): Promise<void> {
  const res = await client(`${WP}/wp-json/wp/v2/posts`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-WP-Nonce": nonce
    },
    body: JSON.stringify({
      title: article.title,
      content: article.content,
      status: "publish"
    })
  });

  if (res.ok) {
    console.log("✅ 記事投稿完了");
  } else {
    const errorText = await res.text();
    console.error(`❌ 記事投稿失敗: status=${res.status} body=${errorText}`);
    throw new Error(`記事投稿失敗: status=${res.status}`);
  }
}

/**
 * 全体の処理フローを実行（ログイン→nonce取得→記事生成→投稿）
 */
async function main() {
  await login();
  const nonce = await getNonce();
  const article = await generateArticle();
  await createPost(nonce, article);
}

await main().catch(e => {
  console.error(e);
  process.exit(1);
});