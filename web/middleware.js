// UPDATE 09 section 2c (T-139): the password gate for the browser build (Vercel Routing Middleware, Edge runtime,
// no framework, no packages). CZ_PASSWORD is a project environment variable; unset = the site is open.
// A correct answer POSTed to /gate sets the cookie cz_gate = sha256("cz:" + password); everything else passes through.
export const config = { matcher: '/((?!_vercel|favicon).*)' };

const COOKIE = 'cz_gate';
const PASS = { headers: { 'x-middleware-next': '1' } };   // what @vercel/functions' next() returns: continue to the files

async function digest(text) {
	const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
	return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function form(msg) {
	const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CLAUDE ZOMBIES</title><style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#08070c;color:#e9e4f2;
font-family:system-ui,sans-serif}form{display:flex;flex-direction:column;gap:12px;width:min(320px,86vw)}h1{letter-spacing:.3em;font-size:22px;margin:0 0 8px}
input,button{font:inherit;padding:10px 12px;border-radius:6px;border:1px solid #3a3150;background:#15111f;color:inherit}
button{background:#8f5cff;border-color:#8f5cff;cursor:pointer}p{color:#e07a8a;margin:0;min-height:1.2em}</style></head>
<body><form method="POST" action="/gate"><h1>CLAUDE ZOMBIES</h1><input type="password" name="password" placeholder="Password" autofocus required>
<button type="submit">Enter</button><p>${msg}</p></form></body></html>`;
	return new Response(html, { status: 401, headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' } });
}

export default async function middleware(request) {
	const pw = process.env.CZ_PASSWORD;
	if (!pw) return new Response(null, PASS);
	const want = await digest('cz:' + pw);
	const url = new URL(request.url);
	if (url.pathname === '/gate' && request.method === 'POST') {
		const data = await request.formData();
		if (String(data.get('password') || '') !== pw) return form('Wrong password.');
		const cookie = `${COOKIE}=${want}; Path=/; Max-Age=2592000; HttpOnly; Secure; SameSite=Lax`;
		return new Response(null, { status: 303, headers: { location: '/', 'set-cookie': cookie, 'cache-control': 'no-store' } });
	}
	const m = (request.headers.get('cookie') || '').match(/(?:^|;\s*)cz_gate=([0-9a-f]{64})/);
	return m && m[1] === want ? new Response(null, PASS) : form('');
}
