import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceKey = Deno.env.get("SERVICE_ROLE_KEY");
const appKey = Deno.env.get("APP_API_KEY");

if (!supabaseUrl || !serviceKey) {
  throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set");
}

const sb = createClient(supabaseUrl, serviceKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-app-key, apikey, content-type, prefer",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, PUT, DELETE, OPTIONS",
};

function withCors(resp: Response) {
  const headers = new Headers(resp.headers);
  for (const [k, v] of Object.entries(corsHeaders)) {
    headers.set(k, v);
  }
  return new Response(resp.body, { status: resp.status, headers });
}

function jsonResponse(data: unknown, status = 200) {
  return withCors(
    new Response(JSON.stringify(data), {
      status,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

async function readJson(req: Request) {
  try {
    return await req.json();
  } catch (_) {
    return null;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return withCors(new Response("ok"));
  }

  if (appKey && req.headers.get("x-app-key") !== appKey) {
    return withCors(new Response("Unauthorized", { status: 401 }));
  }

  const url = new URL(req.url);
  const apiIndex = url.pathname.indexOf("/api");
  const subpath = apiIndex >= 0 ? url.pathname.slice(apiIndex + 4) : url.pathname;
  const path = subpath.startsWith("/") ? subpath : `/${subpath}`;

  // Custom routes the app expects but PostgREST does not provide.
  const batchDetailsMatch = path.match(/^\/rest\/v1\/batches\/([^/]+)\/details$/);
  if (batchDetailsMatch && req.method === "GET") {
    const batchId = batchDetailsMatch[1];

    const { data: batch, error: batchError } = await sb
      .from("batches")
      .select("*")
      .eq("id", batchId)
      .maybeSingle();

    if (batchError) return jsonResponse({ error: batchError.message }, 400);
    if (!batch) return jsonResponse({ error: "Batch not found" }, 404);

    const { data: course } = await sb
      .from("courses")
      .select("title")
      .eq("id", batch.course_id)
      .maybeSingle();

    const { data: mentor } = await sb
      .from("users")
      .select("id,name,email,username")
      .eq("id", batch.mentor_id)
      .maybeSingle();

    const { data: students } = await sb
      .from("users")
      .select("id,name,email,username")
      .eq("batch_id", batchId)
      .eq("role", "student");

    return jsonResponse({
      batch,
      course_name: course?.title,
      mentor,
      students: students ?? [],
      top_performers: [],
      total_students: (students ?? []).length,
      average_progress: 0,
    });
  }

  const topPerformersMatch = path.match(/^\/rest\/v1\/batches\/([^/]+)\/top-performers$/);
  if (topPerformersMatch && req.method === "GET") {
    return jsonResponse([]);
  }

  const batchAnnouncementMatch = path.match(
    /^\/rest\/v1\/notifications\/batches\/([^/]+)\/announcements$/,
  );
  if (batchAnnouncementMatch && req.method === "POST") {
    const batchId = batchAnnouncementMatch[1];
    const body = (await readJson(req)) ?? {};

    const payload = {
      title: body.title ?? "Announcement",
      message: body.message ?? "",
      type: "announcement",
      target_group: "student",
      sender_id: body.sender_id ?? null,
    };

    const { data, error } = await sb.from("notifications").insert(payload).select();
    if (error) return jsonResponse({ error: error.message }, 400);
    return jsonResponse(data ?? []);
  }

  const questionReplyMatch = path.match(/^\/rest\/v1\/questions\/([^/]+)\/reply$/);
  if (questionReplyMatch && req.method === "PATCH") {
    const questionId = questionReplyMatch[1];
    const body = (await readJson(req)) ?? {};

    const { data, error } = await sb
      .from("questions")
      .update({ reply: body.reply ?? "", status: "replied" })
      .eq("id", questionId)
      .select();

    if (error) return jsonResponse({ error: error.message }, 400);
    return jsonResponse((data ?? [])[0] ?? {});
  }

  // Special-case announcements sent via /notifications?type=eq.announcement
  if (path === "/rest/v1/notifications" && req.method === "POST") {
    const body = (await readJson(req)) ?? {};
    if (url.searchParams.get("type") === "eq.announcement") {
      body.type = "announcement";
    }
    const { data, error } = await sb.from("notifications").insert(body).select();
    if (error) return jsonResponse({ error: error.message }, 400);
    return jsonResponse(data ?? []);
  }

  // Proxy all other REST requests to PostgREST with service role.
  const targetUrl = `${supabaseUrl}${path}${url.search}`;
  const headers = new Headers();
  headers.set("apikey", serviceKey);
  headers.set("Authorization", `Bearer ${serviceKey}`);

  const contentType = req.headers.get("content-type");
  if (contentType) headers.set("content-type", contentType);
  const prefer = req.headers.get("prefer");
  if (prefer) headers.set("prefer", prefer);
  const accept = req.headers.get("accept");
  if (accept) headers.set("accept", accept);

  const proxyResp = await fetch(targetUrl, {
    method: req.method,
    headers,
    body: req.method === "GET" || req.method === "HEAD" ? undefined : req.body,
  });

  return withCors(proxyResp);
});
