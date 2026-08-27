import "jsr:@supabase/functions-js@2.112.2/edge-runtime.d.ts";

type Language = "python" | "c";

type ExecuteRequest = {
  language: Language;
  source: string;
  stdin: string;
};

type RunnerResult = {
  stdout: string;
  stderr: string;
  exitCode: number;
  durationMs: number;
  timedOut: boolean;
  truncated: boolean;
  phase: "completed" | "compile" | "runtime";
};

const maxRequestBytes = 32 * 1024;
const maxSourceBytes = 20 * 1024;
const maxStdinBytes = 8 * 1024;
const maxOutputCharacters = 70 * 1024;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const jsonHeaders = {
  ...corsHeaders,
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      throw new HttpError(401, "Please sign in again.");
    }
    const user = await loadAuthenticatedUser(authHeader);
    const body = await parseRequest(request);
    const runner = runnerConfiguration(body.language);

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8_000);
    let response: Response;
    try {
      response = await fetch(runner.url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Runner-Token": runner.secret,
        },
        body: JSON.stringify({
          userId: user.id,
          source: body.source,
          stdin: body.stdin,
        }),
        signal: controller.signal,
      });
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") {
        throw new HttpError(504, "The code runner did not respond in time.");
      }
      throw new HttpError(503, "The secure code runner is unavailable.");
    } finally {
      clearTimeout(timeout);
    }

    const responseText = await readLimitedText(response, 80 * 1024);
    let responseBody: unknown;
    try {
      responseBody = JSON.parse(responseText);
    } catch {
      throw new HttpError(502, "The code runner returned an invalid response.");
    }

    if (!response.ok) {
      const runnerError = responseBody as { error?: unknown };
      const safeMessage = typeof runnerError?.error === "string"
        ? runnerError.error
        : "The code runner could not execute this program.";
      const status = response.status === 429 ? 429 : 502;
      throw new HttpError(status, safeMessage);
    }

    return json(validateRunnerResult(responseBody));
  } catch (error) {
    if (error instanceof HttpError) {
      return json({ error: error.message }, error.status);
    }
    console.error(
      "Code execution relay failed",
      error instanceof Error ? error.message : "Unknown error",
    );
    return json({ error: "Could not run the program." }, 500);
  }
});

class HttpError extends Error {
  constructor(public readonly status: number, message: string) {
    super(message);
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

async function parseRequest(request: Request): Promise<ExecuteRequest> {
  const contentLength = Number(request.headers.get("Content-Length") ?? "0");
  if (Number.isFinite(contentLength) && contentLength > maxRequestBytes) {
    throw new HttpError(413, "The execution request is too large.");
  }

  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > maxRequestBytes) {
    throw new HttpError(413, "The execution request is too large.");
  }

  let value: unknown;
  try {
    value = JSON.parse(rawBody);
  } catch {
    throw new HttpError(400, "Invalid execution request.");
  }
  if (!value || typeof value !== "object") {
    throw new HttpError(400, "Invalid execution request.");
  }

  const body = value as Record<string, unknown>;
  const language = requiredLanguage(body.language);
  const label = language === "python" ? "Python" : "C";
  const source = requiredString(body.source, `${label} source`);
  const stdin = optionalString(body.stdin, "Program input");
  const encoder = new TextEncoder();
  if (encoder.encode(source).byteLength > maxSourceBytes) {
    throw new HttpError(400, `${label} source must be 20 KB or less.`);
  }
  if (encoder.encode(stdin).byteLength > maxStdinBytes) {
    throw new HttpError(400, "Program input must be 8 KB or less.");
  }
  if (source.includes("\u0000") || stdin.includes("\u0000")) {
    throw new HttpError(400, "The execution request contains invalid text.");
  }
  return { language, source, stdin };
}

function requiredLanguage(value: unknown): Language {
  if (value !== "python" && value !== "c") {
    throw new HttpError(400, "Choose Python or C before running code.");
  }
  return value;
}

function requiredString(value: unknown, label: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpError(400, `${label} is required.`);
  }
  return value;
}

function optionalString(value: unknown, label: string): string {
  if (value === undefined || value === null) return "";
  if (typeof value !== "string") {
    throw new HttpError(400, `${label} is invalid.`);
  }
  return value;
}

function runnerConfiguration(language: Language): { url: string; secret: string } {
  const configuredUrl = Deno.env.get("CODE_RUNNER_URL")?.trim();
  const secret = Deno.env.get("CODE_RUNNER_SHARED_SECRET")?.trim();
  if (!configuredUrl || !secret || secret.length < 32) {
    throw new HttpError(503, "The secure code runner is not configured.");
  }

  let baseUrl: URL;
  try {
    baseUrl = new URL(configuredUrl);
  } catch {
    throw new HttpError(503, "The secure code runner is not configured.");
  }
  if (baseUrl.protocol !== "https:") {
    throw new HttpError(503, "The secure code runner requires HTTPS.");
  }
  return {
    url: new URL(`/v1/execute/${language}`, baseUrl).toString(),
    secret,
  };
}

function validateRunnerResult(value: unknown): RunnerResult {
  if (!value || typeof value !== "object") {
    throw new HttpError(502, "The code runner returned an invalid response.");
  }
  const result = value as Record<string, unknown>;
  const { stdout, stderr, exitCode, durationMs, timedOut, truncated } = result;
  const phase = result.phase ??
    (exitCode === 0 && timedOut === false ? "completed" : "runtime");
  if (
    typeof stdout !== "string" ||
    typeof stderr !== "string" ||
    typeof exitCode !== "number" ||
    !Number.isInteger(exitCode) ||
    typeof durationMs !== "number" ||
    !Number.isInteger(durationMs) ||
    typeof timedOut !== "boolean" ||
    typeof truncated !== "boolean" ||
    (phase !== "completed" && phase !== "compile" && phase !== "runtime") ||
    stdout.length + stderr.length > maxOutputCharacters
  ) {
    throw new HttpError(502, "The code runner returned an invalid response.");
  }
  return { stdout, stderr, exitCode, durationMs, timedOut, truncated, phase };
}

async function readLimitedText(
  response: Response,
  maximumBytes: number,
): Promise<string> {
  if (!response.body) return "";
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let totalBytes = 0;
  let text = "";
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > maximumBytes) {
        await reader.cancel();
        throw new HttpError(502, "The code runner returned too much output.");
      }
      text += decoder.decode(value, { stream: true });
    }
    return text + decoder.decode();
  } finally {
    reader.releaseLock();
  }
}

function getPublishableKey(): string {
  const legacyKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (legacyKey) return legacyKey;
  const singleKey = Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  if (singleKey) return singleKey;
  const keys = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (!keys) throw new HttpError(503, "Supabase authentication is unavailable.");
  const parsed = JSON.parse(keys) as Record<string, string>;
  if (!parsed.default) {
    throw new HttpError(503, "Supabase authentication is unavailable.");
  }
  return parsed.default;
}

function getSupabaseUrl(): string {
  const url = Deno.env.get("SUPABASE_URL");
  if (!url) throw new HttpError(503, "Supabase is not configured.");
  return url;
}

async function loadAuthenticatedUser(
  authHeader: string,
): Promise<{ id: string }> {
  const response = await fetch(`${getSupabaseUrl()}/auth/v1/user`, {
    headers: {
      apikey: getPublishableKey(),
      Authorization: authHeader,
    },
  });
  if (!response.ok) {
    throw new HttpError(401, "Your session has expired. Sign in again.");
  }
  const user = await response.json() as { id?: string };
  if (!user.id) {
    throw new HttpError(401, "Your session has expired. Sign in again.");
  }
  return { id: user.id };
}
