# BitClass Code Runner

This service runs one Python or C file per disposable gVisor container. It is
intended for a dedicated Linux host and must not share a machine with Supabase,
databases, CI workers, or other sensitive services.

## Security boundary

Each execution uses a fixed command and enforces:

- gVisor's `runsc` OCI runtime
- no container network
- non-root user and all Linux capabilities dropped
- read-only root filesystem with no host directory mounted
- a bounded memory limit (1 GB by default), 0.5 CPU, 32 process, 256 open
  file, and 5 second limits
- 32 KB each for stdout and stderr
- no image pulls during requests
- immediate container cleanup

The service sends bounded source and program input to fixed, language-specific
bootstraps over standard input. C source is compiled as C17 with a fixed GCC
command before its temporary binary is executed. It does not accept shell
commands, filenames, compiler arguments, packages, environment variables, or
mounts from the caller, and it logs neither source code nor program input.

## Host setup

1. Provision a dedicated Linux VM.
2. Install Docker Engine and gVisor, then configure Docker's `runsc` runtime.
3. Verify isolation with `docker run --rm --runtime=runsc hello-world`.
4. Pull approved Python and GCC images as an administrator.
5. Record both immutable digests with
   `docker image inspect --format '{{index .RepoDigests 0}}' IMAGE_NAME`.
6. Set the variables shown in `.env.example`. Use the same random shared secret
   for `CODE_RUNNER_SHARED_SECRET` in Supabase.
   Size `RUNNER_MAX_CONCURRENT` so its combined memory limits leave capacity for
   the host; the example uses one 1 GB job on a 2 GB VM.
7. Start the service with `dart run bin/server.dart` from this directory.
8. Place an HTTPS reverse proxy in front of the loopback listener and allow
   requests only from the Supabase relay where infrastructure permits.

The service intentionally refuses to start on Windows or macOS. Membership in
the Docker group is effectively privileged host access, which is why this must
run on an otherwise disposable, dedicated VM.

## Health check

`GET /healthz` returns `{"status":"ok"}` without running a container. Program
execution requires `POST /v1/execute/python` or `POST /v1/execute/c` with the
private `X-Runner-Token` header. Never expose that token to Flutter clients.
