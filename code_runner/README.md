# BitClass Code Runner

This service runs one Python file per disposable gVisor container. It is
intended for a dedicated Linux host and must not share a machine with Supabase,
databases, CI workers, or other sensitive services.

## Security boundary

Each execution uses a fixed command and enforces:

- gVisor's `runsc` OCI runtime
- no container network
- non-root user and all Linux capabilities dropped
- read-only root filesystem and source mount
<<<<<<< HEAD
- a bounded memory limit (1 GB by default), 0.5 CPU, 32 process, 256 open
  file, and 5 second limits
=======
- a bounded memory limit (512 MB by default), 0.5 CPU, 32 process, and 5
  second limits
>>>>>>> 183c496669d7a2cd43bd71dc171b6b070aa75846
- 32 KB each for stdout and stderr
- no image pulls during requests
- immediate container and workspace deletion

The service does not accept shell commands, filenames, compiler arguments,
packages, environment variables, or mounts from the caller. It logs neither
source code nor program input.

## Host setup

1. Provision a dedicated Linux VM.
2. Install Docker Engine and gVisor, then configure Docker's `runsc` runtime.
3. Verify isolation with `docker run --rm --runtime=runsc hello-world`.
4. Pull an approved Python image as an administrator.
5. Record its immutable digest with
   `docker image inspect --format '{{index .RepoDigests 0}}' IMAGE_NAME`.
6. Set the variables shown in `.env.example`. Use the same random shared secret
   for `CODE_RUNNER_SHARED_SECRET` in Supabase.
   Size `RUNNER_MAX_CONCURRENT` so its combined memory limits leave capacity for
<<<<<<< HEAD
   the host; the example uses one 1 GB job on a 2 GB VM.
=======
   the host; the example uses two 512 MB jobs on a 2 GB VM.
>>>>>>> 183c496669d7a2cd43bd71dc171b6b070aa75846
7. Start the service with `dart run bin/server.dart` from this directory.
8. Place an HTTPS reverse proxy in front of the loopback listener and allow
   requests only from the Supabase relay where infrastructure permits.

The service intentionally refuses to start on Windows or macOS. Membership in
the Docker group is effectively privileged host access, which is why this must
run on an otherwise disposable, dedicated VM.

## Health check

`GET /healthz` returns `{"status":"ok"}` without running a container. Program
execution requires `POST /v1/execute/python` with the private `X-Runner-Token`
header. Never expose that token to Flutter clients.
