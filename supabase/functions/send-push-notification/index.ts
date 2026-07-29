import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type NotificationRecord = {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string;
  image_url?: string | null;
  data?: Record<string, unknown> | null;
  course_id?: string | null;
  action_url?: string | null;
};

type WebhookPayload = {
  type: "INSERT";
  schema: "public";
  table: "notifications";
  record: NotificationRecord;
};

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

type DeviceToken = {
  token: string;
  timezone_offset_minutes: number;
};

type NotificationPreferences = {
  push_enabled: boolean;
  type_settings: Record<string, boolean>;
  quiet_hours_enabled: boolean;
  quiet_hours_start: number;
  quiet_hours_end: number;
};

let cachedAccessToken: { value: string; expiresAt: number } | null = null;

const jsonHeaders = { "Content-Type": "application/json" };

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const configuredSecret = Deno.env.get("PUSH_WEBHOOK_SECRET");
  const suppliedSecret = request.headers.get("x-bitclass-webhook-secret");
  if (
    !configuredSecret ||
    !suppliedSecret ||
    !(await secretsMatch(configuredSecret, suppliedSecret))
  ) {
    return json({ error: "Unauthorized" }, 401);
  }

  try {
    const payload = (await request.json()) as WebhookPayload;
    if (
      payload.type !== "INSERT" ||
      payload.schema !== "public" ||
      payload.table !== "notifications" ||
      !payload.record?.id ||
      !payload.record?.user_id
    ) {
      return json({ error: "Invalid notification webhook payload" }, 400);
    }

    const preferences = await loadPreferences(payload.record.user_id);
    if (!shouldDeliver(payload.record.type, preferences)) {
      return json({ delivered: 0, skipped: "user_preferences" });
    }

    const tokens = await loadDeviceTokens(payload.record.user_id);
    const eligibleTokens = tokens.filter(
      (token) => !isQuietHour(preferences, token.timezone_offset_minutes),
    );
    if (eligibleTokens.length === 0) {
      return json({ delivered: 0, skipped: "no_eligible_devices" });
    }

    const serviceAccount = loadServiceAccount();
    const accessToken = await getAccessToken(serviceAccount);
    const results = await Promise.all(
      eligibleTokens.map((device) =>
        sendToDevice(serviceAccount, accessToken, device, payload.record)
      ),
    );

    return json({
      delivered: results.filter((result) => result === "sent").length,
      invalid_tokens_removed: results.filter(
        (result) => result === "invalid_removed",
      ).length,
      failed: results.filter((result) => result === "failed").length,
    });
  } catch (error) {
    console.error("Push dispatch failed", error);
    return json(
      {
        error: error instanceof Error ? error.message : "Push dispatch failed",
      },
      500,
    );
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

async function secretsMatch(expected: string, actual: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const [expectedHash, actualHash] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
    crypto.subtle.digest("SHA-256", encoder.encode(actual)),
  ]);
  const expectedBytes = new Uint8Array(expectedHash);
  const actualBytes = new Uint8Array(actualHash);
  let difference = 0;
  for (let index = 0; index < expectedBytes.length; index += 1) {
    difference |= expectedBytes[index] ^ actualBytes[index];
  }
  return difference === 0;
}

function getSupabaseSecret(): string {
  const legacySecret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacySecret) return legacySecret;

  const secretKeys = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!secretKeys) throw new Error("Supabase server secret is not configured");
  return JSON.parse(secretKeys).default;
}

async function supabaseRequest<T>(
  path: string,
  init?: RequestInit,
): Promise<T> {
  const url = Deno.env.get("SUPABASE_URL");
  if (!url) throw new Error("SUPABASE_URL is not configured");
  const secret = getSupabaseSecret();
  const authorizationHeader = secret.startsWith("sb_secret_")
    ? {}
    : { Authorization: `Bearer ${secret}` };
  const response = await fetch(`${url}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: secret,
      ...authorizationHeader,
      ...jsonHeaders,
      ...(init?.headers ?? {}),
    },
  });
  if (!response.ok) {
    throw new Error(`Supabase request failed (${response.status})`);
  }
  if (response.status === 204) return undefined as T;
  return (await response.json()) as T;
}

async function loadPreferences(userId: string): Promise<NotificationPreferences> {
  const rows = await supabaseRequest<NotificationPreferences[]>(
    `notification_settings?user_id=eq.${encodeURIComponent(userId)}` +
      "&select=push_enabled,type_settings,quiet_hours_enabled," +
      "quiet_hours_start,quiet_hours_end&limit=1",
  );
  return rows[0] ?? {
    push_enabled: true,
    type_settings: {},
    quiet_hours_enabled: false,
    quiet_hours_start: 22,
    quiet_hours_end: 8,
  };
}

async function loadDeviceTokens(userId: string): Promise<DeviceToken[]> {
  return await supabaseRequest<DeviceToken[]>(
    `device_tokens?user_id=eq.${encodeURIComponent(userId)}` +
      "&select=token,timezone_offset_minutes",
  );
}

function shouldDeliver(
  type: string,
  preferences: NotificationPreferences,
): boolean {
  return preferences.push_enabled && preferences.type_settings[type] !== false;
}

function isQuietHour(
  preferences: NotificationPreferences,
  timezoneOffsetMinutes: number,
): boolean {
  if (!preferences.quiet_hours_enabled) return false;
  const localNow = new Date(Date.now() + timezoneOffsetMinutes * 60_000);
  const hour = localNow.getUTCHours();
  const start = preferences.quiet_hours_start;
  const end = preferences.quiet_hours_end;
  if (start === end) return true;
  return start < end ? hour >= start && hour < end : hour >= start || hour < end;
}

function loadServiceAccount(): ServiceAccount {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON is not configured");
  const account = JSON.parse(raw) as ServiceAccount;
  if (!account.project_id || !account.client_email || !account.private_key) {
    throw new Error("Firebase service account JSON is incomplete");
  }
  return account;
}

async function getAccessToken(account: ServiceAccount): Promise<string> {
  if (cachedAccessToken && cachedAccessToken.expiresAt > Date.now() + 60_000) {
    return cachedAccessToken.value;
  }

  const issuedAt = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(
    JSON.stringify({
      iss: account.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: account.token_uri ?? "https://oauth2.googleapis.com/token",
      iat: issuedAt,
      exp: issuedAt + 3600,
    }),
  );
  const unsignedToken = `${header}.${claims}`;
  const privateKey = await importPrivateKey(account.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(unsignedToken),
  );
  const assertion = `${unsignedToken}.${base64UrlBytes(
    new Uint8Array(signature),
  )}`;

  const tokenResponse = await fetch(
    account.token_uri ?? "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    },
  );
  if (!tokenResponse.ok) {
    throw new Error(`Google OAuth failed (${tokenResponse.status})`);
  }
  const tokenJson = await tokenResponse.json();
  cachedAccessToken = {
    value: tokenJson.access_token,
    expiresAt: Date.now() + Number(tokenJson.expires_in ?? 3600) * 1000,
  };
  return cachedAccessToken.value;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const normalized = pem.replace(/\\n/g, "\n");
  const base64 = normalized
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = Uint8Array.from(atob(base64), (character) =>
    character.charCodeAt(0)
  );
  return await crypto.subtle.importKey(
    "pkcs8",
    binary,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

function base64Url(value: string): string {
  return base64UrlBytes(new TextEncoder().encode(value));
}

function base64UrlBytes(value: Uint8Array): string {
  let binary = "";
  value.forEach((byte) => (binary += String.fromCharCode(byte)));
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function sendToDevice(
  account: ServiceAccount,
  accessToken: string,
  device: DeviceToken,
  notification: NotificationRecord,
): Promise<"sent" | "invalid_removed" | "failed"> {
  const data = Object.fromEntries(
    Object.entries({
      ...(notification.data ?? {}),
      notification_id: notification.id,
      notification_type: notification.type,
      course_id: notification.course_id,
      action_url: notification.action_url,
      title: notification.title,
      body: notification.body,
    })
      .filter(([, value]) => value !== null && value !== undefined)
      .map(([key, value]) => [
        key,
        typeof value === "string" ? value : JSON.stringify(value),
      ]),
  );

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${
      encodeURIComponent(account.project_id)
    }/messages:send`,
    {
      method: "POST",
      headers: {
        ...jsonHeaders,
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: device.token,
          notification: {
            title: notification.title,
            body: notification.body,
            ...(notification.image_url
              ? { image: notification.image_url }
              : {}),
          },
          data,
          android: {
            priority: "high",
            notification: {
              channel_id: "bitclass_updates",
              sound: "default",
            },
          },
          apns: {
            payload: { aps: { sound: "default", badge: 1 } },
          },
        },
      }),
    },
  );

  if (response.ok) return "sent";

  const errorBody = await response.text();
  const invalid =
    response.status === 404 ||
    errorBody.includes("UNREGISTERED") ||
    (response.status === 400 && errorBody.includes("registration token"));
  if (invalid) {
    await supabaseRequest<void>(
      `device_tokens?token=eq.${encodeURIComponent(device.token)}`,
      { method: "DELETE", headers: { Prefer: "return=minimal" } },
    );
    return "invalid_removed";
  }

  console.error("FCM send failed", response.status, errorBody);
  return "failed";
}
