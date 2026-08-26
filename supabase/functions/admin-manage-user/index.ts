import "jsr:@supabase/functions-js@2.112.2/edge-runtime.d.ts";

type UserRole = "student" | "instructor" | "admin";

type ManageUserRequest =
  | {
    action: "set_role";
    user_id: string;
    role: UserRole;
    reason?: string;
  }
  | {
    action: "set_suspension";
    user_id: string;
    suspended: boolean;
    reason?: string;
  };

type ProfileRecord = {
  id: string;
  email: string;
  display_name?: string | null;
  first_name?: string | null;
  last_name?: string | null;
  avatar_url?: string | null;
  role: UserRole;
  is_suspended: boolean;
  suspended_at?: string | null;
  suspended_by?: string | null;
  created_at?: string | null;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonHeaders = {
  ...corsHeaders,
  "Content-Type": "application/json",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const actor = await authenticateCaller(request);
    const actorProfile = await loadProfile(actor.id);
    if (
      !actorProfile ||
      actorProfile.role !== "admin" ||
      actorProfile.is_suspended
    ) {
      return json({ error: "Administrator access required" }, 403);
    }

    const payload = validatePayload(await request.json());
    const target = await loadProfile(payload.user_id);
    if (!target) return json({ error: "User profile not found" }, 404);

    if (
      target.id === actor.id &&
      ((payload.action === "set_role" && payload.role !== "admin") ||
        (payload.action === "set_suspension" && payload.suspended))
    ) {
      return json(
        { error: "You cannot remove or suspend your own administrator access" },
        409,
      );
    }

    const updated = payload.action === "set_role"
      ? await changeRole(actorProfile, target, payload.role, payload.reason)
      : await changeSuspension(
        actorProfile,
        target,
        payload.suspended,
        payload.reason,
      );

    return json({ user: updated });
  } catch (error) {
    console.error("Admin user management failed", error);
    if (error instanceof RequestError) {
      return json({ error: error.message }, error.status);
    }
    return json({ error: "The admin action could not be completed" }, 500);
  }
});

class RequestError extends Error {
  constructor(message: string, readonly status = 400) {
    super(message);
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function validatePayload(value: unknown): ManageUserRequest {
  if (!value || typeof value !== "object") {
    throw new RequestError("A JSON request body is required");
  }
  const input = value as Record<string, unknown>;
  const userId = typeof input.user_id === "string" ? input.user_id.trim() : "";
  if (!isUuid(userId)) throw new RequestError("A valid user_id is required");

  const reason = typeof input.reason === "string" ? input.reason.trim() : "";
  if (reason.length > 500) {
    throw new RequestError("The reason must be 500 characters or fewer");
  }

  if (input.action === "set_role") {
    if (!isUserRole(input.role)) throw new RequestError("Invalid user role");
    return {
      action: "set_role",
      user_id: userId,
      role: input.role,
      ...(reason ? { reason } : {}),
    };
  }

  if (input.action === "set_suspension") {
    if (typeof input.suspended !== "boolean") {
      throw new RequestError("suspended must be true or false");
    }
    return {
      action: "set_suspension",
      user_id: userId,
      suspended: input.suspended,
      ...(reason ? { reason } : {}),
    };
  }

  throw new RequestError("Unsupported admin action");
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function isUserRole(value: unknown): value is UserRole {
  return value === "student" || value === "instructor" || value === "admin";
}

async function authenticateCaller(request: Request): Promise<{ id: string }> {
  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    throw new RequestError("Authentication required", 401);
  }

  const response = await fetch(`${supabaseUrl()}/auth/v1/user`, {
    headers: {
      apikey: getPublishableKey(),
      Authorization: authorization,
    },
  });
  if (!response.ok) throw new RequestError("Invalid or expired session", 401);

  const user = await response.json() as { id?: string };
  if (!user.id) throw new RequestError("Invalid user session", 401);
  return { id: user.id };
}

async function loadProfile(userId: string): Promise<ProfileRecord | null> {
  const rows = await serviceRequest<ProfileRecord[]>(
    `profiles?id=eq.${encodeURIComponent(userId)}` +
      "&select=id,email,display_name,first_name,last_name,avatar_url,role," +
      "is_suspended,suspended_at,suspended_by,created_at&limit=1",
  );
  return rows[0] ?? null;
}

async function changeRole(
  actor: ProfileRecord,
  target: ProfileRecord,
  role: UserRole,
  reason?: string,
): Promise<ProfileRecord> {
  if (target.role === role) return target;

  const updated = await updateProfile(target.id, { role });
  try {
    await writeAudit({
      actor,
      action: "user.role_changed",
      target,
      reason,
      previousValues: { role: target.role },
      newValues: { role },
    });
  } catch (error) {
    await updateProfile(target.id, { role: target.role });
    throw error;
  }
  return updated;
}

async function changeSuspension(
  actor: ProfileRecord,
  target: ProfileRecord,
  suspended: boolean,
  reason?: string,
): Promise<ProfileRecord> {
  if (target.is_suspended === suspended) return target;

  await updateAuthBan(target.id, suspended);
  let updated: ProfileRecord;
  try {
    updated = await updateProfile(target.id, {
      is_suspended: suspended,
      suspended_at: suspended ? new Date().toISOString() : null,
      suspended_by: suspended ? actor.id : null,
    });
  } catch (error) {
    await updateAuthBan(target.id, target.is_suspended);
    throw error;
  }

  try {
    await writeAudit({
      actor,
      action: suspended ? "user.suspended" : "user.restored",
      target,
      reason,
      previousValues: { is_suspended: target.is_suspended },
      newValues: { is_suspended: suspended },
    });
  } catch (error) {
    await updateProfile(target.id, {
      is_suspended: target.is_suspended,
      suspended_at: target.suspended_at ?? null,
      suspended_by: target.suspended_by ?? null,
    });
    await updateAuthBan(target.id, target.is_suspended);
    throw error;
  }
  return updated;
}

async function updateProfile(
  userId: string,
  values: Record<string, unknown>,
): Promise<ProfileRecord> {
  const rows = await serviceRequest<ProfileRecord[]>(
    `profiles?id=eq.${encodeURIComponent(userId)}` +
      "&select=id,email,display_name,first_name,last_name,avatar_url,role," +
      "is_suspended,suspended_at,suspended_by,created_at",
    {
      method: "PATCH",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify(values),
    },
  );
  if (!rows[0]) throw new Error("Profile update returned no user");
  return rows[0];
}

async function updateAuthBan(userId: string, suspended: boolean): Promise<void> {
  await serviceRequest<unknown>(
    `../auth/v1/admin/users/${encodeURIComponent(userId)}`,
    {
      method: "PUT",
      body: JSON.stringify({ ban_duration: suspended ? "876000h" : "none" }),
    },
  );
}

async function writeAudit(input: {
  actor: ProfileRecord;
  action: string;
  target: ProfileRecord;
  reason?: string;
  previousValues: Record<string, unknown>;
  newValues: Record<string, unknown>;
}): Promise<void> {
  await serviceRequest<unknown>("admin_audit_logs", {
    method: "POST",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify({
      actor_id: input.actor.id,
      actor_email: input.actor.email,
      action: input.action,
      target_type: "user",
      target_id: input.target.id,
      reason: input.reason ?? null,
      previous_values: input.previousValues,
      new_values: {
        ...input.newValues,
        target_email: input.target.email,
      },
    }),
  });
}

async function serviceRequest<T>(path: string, init?: RequestInit): Promise<T> {
  const secret = getSecretKey();
  const isAuthPath = path.startsWith("../auth/");
  const url = isAuthPath
    ? `${supabaseUrl()}/${path.substring(3)}`
    : `${supabaseUrl()}/rest/v1/${path}`;
  const response = await fetch(url, {
    ...init,
    headers: {
      apikey: secret,
      ...(secret.startsWith("sb_secret_")
        ? {}
        : { Authorization: `Bearer ${secret}` }),
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });
  if (!response.ok) {
    const details = await response.text();
    console.error("Supabase service request failed", response.status, details);
    throw new Error(`Supabase service request failed (${response.status})`);
  }
  if (response.status === 204 || response.headers.get("content-length") === "0") {
    return undefined as T;
  }
  return await response.json() as T;
}

function supabaseUrl(): string {
  const value = Deno.env.get("SUPABASE_URL");
  if (!value) throw new Error("SUPABASE_URL is not configured");
  return value.replace(/\/$/, "");
}

function getPublishableKey(): string {
  const legacy = Deno.env.get("SUPABASE_ANON_KEY");
  if (legacy) return legacy;
  return readNamedKey("SUPABASE_PUBLISHABLE_KEYS", "publishable");
}

function getSecretKey(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  return readNamedKey("SUPABASE_SECRET_KEYS", "secret");
}

function readNamedKey(environmentName: string, label: string): string {
  const raw = Deno.env.get(environmentName);
  if (!raw) throw new Error(`Supabase ${label} key is not configured`);
  const values = JSON.parse(raw) as Record<string, string>;
  const value = values.default ?? Object.values(values)[0];
  if (!value) throw new Error(`Supabase ${label} key is not configured`);
  return value;
}
