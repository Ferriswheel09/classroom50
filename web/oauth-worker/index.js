/**
 * Cloudflare Worker: GitHub OAuth token exchange proxy.
 * Keeps the client secret out of the browser.
 *
 * Deploy with: wrangler deploy
 * Set secret:  wrangler secret put GITHUB_CLIENT_SECRET
 *
 * Env vars (wrangler.toml or dashboard):
 *   GITHUB_CLIENT_SECRET  — your OAuth app's client secret (set as a secret)
 *   ALLOWED_ORIGINS       — comma-separated allowed origins, e.g.
 *                           "http://localhost:5173,https://yourdomain.com"
 */

const GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token"

function corsHeaders(origin, env) {
  const allowed = (env.ALLOWED_ORIGINS ?? "").split(",").map((s) => s.trim())
  const allowedOrigin = allowed.includes(origin) ? origin : allowed[0] ?? "*"
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Accept",
  }
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") ?? ""
    const url = new URL(request.url)

    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(origin, env) })
    }

    // POST /web/token — PKCE web flow token exchange
    if (request.method === "POST" && url.pathname === "/web/token") {
      let body
      try {
        body = await request.json()
      } catch {
        return new Response(JSON.stringify({ error: "invalid_request", error_description: "Expected JSON body" }), {
          status: 400,
          headers: { "Content-Type": "application/json", ...corsHeaders(origin, env) },
        })
      }

      const { client_id, code, redirect_uri, code_verifier } = body ?? {}
      if (!client_id || !code) {
        return new Response(JSON.stringify({ error: "invalid_request", error_description: "Missing client_id or code" }), {
          status: 400,
          headers: { "Content-Type": "application/json", ...corsHeaders(origin, env) },
        })
      }

      const params = new URLSearchParams({
        client_id,
        client_secret: env.GITHUB_CLIENT_SECRET ?? "",
        code,
        redirect_uri: redirect_uri ?? "",
      })
      if (code_verifier) params.set("code_verifier", code_verifier)

      const ghRes = await fetch(GITHUB_TOKEN_URL, {
        method: "POST",
        headers: { Accept: "application/json", "Content-Type": "application/x-www-form-urlencoded" },
        body: params.toString(),
      })

      const data = await ghRes.json()
      return new Response(JSON.stringify(data), {
        status: ghRes.ok ? 200 : ghRes.status,
        headers: { "Content-Type": "application/json", ...corsHeaders(origin, env) },
      })
    }

    // POST /device/code — device flow code request (proxied to avoid CORS)
    if (request.method === "POST" && url.pathname === "/device/code") {
      let body
      try {
        body = await request.json()
      } catch {
        return new Response(JSON.stringify({ error: "invalid_request" }), {
          status: 400,
          headers: { "Content-Type": "application/json", ...corsHeaders(origin, env) },
        })
      }

      const ghRes = await fetch("https://github.com/login/device/code", {
        method: "POST",
        headers: { Accept: "application/json", "Content-Type": "application/json" },
        body: JSON.stringify(body),
      })

      const data = await ghRes.json()
      return new Response(JSON.stringify(data), {
        status: ghRes.ok ? 200 : ghRes.status,
        headers: { "Content-Type": "application/json", ...corsHeaders(origin, env) },
      })
    }

    // POST /device/token — device flow token poll
    if (request.method === "POST" && url.pathname === "/device/token") {
      let body
      try {
        body = await request.json()
      } catch {
        return new Response(JSON.stringify({ error: "invalid_request" }), {
          status: 400,
          headers: { "Content-Type": "application/json", ...corsHeaders(origin, env) },
        })
      }

      const params = new URLSearchParams({
        client_id: body.client_id ?? "",
        client_secret: env.GITHUB_CLIENT_SECRET ?? "",
        device_code: body.device_code ?? "",
        grant_type: "urn:ietf:params:oauth:grant-type:device_code",
      })

      const ghRes = await fetch(GITHUB_TOKEN_URL, {
        method: "POST",
        headers: { Accept: "application/json", "Content-Type": "application/x-www-form-urlencoded" },
        body: params.toString(),
      })

      const data = await ghRes.json()
      return new Response(JSON.stringify(data), {
        status: ghRes.ok ? 200 : ghRes.status,
        headers: { "Content-Type": "application/json", ...corsHeaders(origin, env) },
      })
    }

    return new Response("Not found", { status: 404, headers: corsHeaders(origin, env) })
  },
}
